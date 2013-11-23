//+------------------------------------------------------------------+
//|                                                          3MM.mq4 |
//|                André Duarte de Novais, Cássio Jandir Pagnoncelli |
//|                                     http://www.inf.ufpr.br/cjp07 |
//+------------------------------------------------------------------+
#property copyright "André Duarte de Novais, Cássio Jandir Pagnoncelli"
#property link      "http://www.inf.ufpr.br/cjp07"
#define versao "1.0.2"

/* identificador das posições do expert */
#define MAGIC_NUM 5056

/* bibliotecas */
#include <stderror.mqh>
#include <stdlib.mqh>

/* parâmetros. */
extern string   str0                  = "Médias Móveis";
extern int      Periodo_MM_Lenta      = 80;
extern int      Periodo_MM_Media      = 15;
extern int      Periodo_MM_Rapida     = 5;
extern bool  Aguardar_Formacao_Candle = true;
extern string   str1                  = "Timeframe maior (Diretor)";
extern string   tf_explicacao         = "0:desligado; 1:M5; 2:M15; 3:M30; 4:H1;5:H4; 6:D1; 7:W1; 8:MN1";
extern int      TimeFrameDiretor      = 0;
extern int      MM_lenta_Diretor      = 80;
extern int      MM_rapida_Diretor     = 15;
extern string   str2                  = "Retas de Regressão";
extern bool Mostrar_Retas_Regressao   = false;
extern bool Filtro_Horario_nas_Retas  = false;
extern int      Reta_Regressao_Media  = 10;
extern int      Reta_Regressao_Rapida = 8;
extern bool Comentarios_Regressao     = true;
extern string   str3                  = "Manejo de Risco";
extern double   Tamanho_Posicao       = 0.1;
extern int      SL_pips               = 50;
extern bool     SL_fixo               = false;
extern int      TP_N1_pips            = 20;
extern double   TP_N1_liquidar        = 0.5;
extern int      TP_N2_pips            = 50;
extern double   TP_N2_liquidar        = 0.3;
extern int      TP_N3_pips            = 100;
extern bool     Desenhar_TP_e_SL      = true;
extern string   str4                  = "Filtro de Horário";
extern bool Aplicar_Filtro_de_Horario = false;
extern int      GMT_do_Servidor       = 3;
extern datetime Horario_Inicio        = D'1970.01.01 00:00';
extern datetime Horario_Fim           = D'1970.01.01 13:00';

/* enumeração dos níveis de take profit. */
#define INVALIDO -1
#define ABERTURA 0
#define TPN1_ATINGIDO 1
#define TPN2_ATINGIDO 2

/* enumeração dos estados que determinam a tendência dada pelo timeframe diretor */
#define DIRETOR_NOP 0
#define DIRETOR_ALTA 1
#define DIRETOR_BAIXA 2

/* variáveis internas */
double pip;                         // valor do pip para o instrumento (ex.: pip do EURUSD = 0.0001)
bool trava_trade;                   // trava booleana para barrar novos trades
datetime trava_tempo;               // trava temporal para barrar novos trades
int shift_MMs;                      // shift para aguardar a formação de candles
bool indicar_sucesso_posicoes;      // desenhar (V) e (X) sob as posições depois da execução
int hist_index[1024], hist_index_i; // registro das ordens das posições abertas (p/ desenhar (V) e (X).)
int time_frame_diretor,             // timeframe diretor
    tendencia_diretor;              // tendência que o timeframe diretor determina


/* variáveis de depuração */
bool imprimir_estados;              // imprime o conteúdo dos vetores de estados

/* configuração dos estados de níveis de take profit. */
bool q_valido[1];                   // status (válido ou inválido) do estado da posição
int q_id[1];                        // ticket da posição
int q_estado[1];                    // estado (abertura, TPN1, ...) da posição

/* reconhecimento de padrões */
bool gerar_vetores_caracteristicas; // habilitar/desabilitar coleta e geração de dados
int fp;                             // handler do arquivo no qual serão gravados os vetores de caract.
int param_a_i;                      // contador do número de vetores de características
double param_a[1024];               // primeiro eixo dos vetores
datetime registro_ultimo_candle;    // trava temporal para barrar aquisição de característica
double BalancoInicial;              // valor de depósito

/*
  init, deinit, start.
*/
int init()
{
  // otimização para remover desenhos de níveis de TP e SL
  // em modo de otimização e modo não visual (em que não há gráfico)
  HideTestIndicators(false);
  if (IsOptimization() || !IsVisualMode())
    Desenhar_TP_e_SL = false;
  
  // indicar succeso das posições
  hist_index_i = 0;                 // contador de posições abertas
  if (IsTesting() && !IsOptimization())
    indicar_sucesso_posicoes = true;
  else
    indicar_sucesso_posicoes = false;
  
  // depuração
  imprimir_estados = false;
  
  // busca valor do pip em termos da moeda base
  pip = BuscaPip();
  Print("Valor do pip configurado para " + DoubleToStr(pip, 1 - (MathLog(pip)/MathLog(10)))
    + " em termos da moeda base.");
  
  // trava pra não fazer negociações é desabilitada
  trava_trade = false;
  trava_tempo = D'1970.01.01 00:00';
  
  // aguardar o candle se formar pra analisar o cruzamento de MMs;
  // o que se faz é analisar a MM nos dois candles anteriores.
  if (Aguardar_Formacao_Candle)
    shift_MMs = 1;
  else
    shift_MMs = 0;
  
  // configuração do timeframe superior
  tendencia_diretor = DIRETOR_NOP;
  time_frame_diretor = 0;
  switch (TimeFrameDiretor) {
  case 0: time_frame_diretor = 0; break;
  case 1: time_frame_diretor = PERIOD_M5; break;
  case 2: time_frame_diretor = PERIOD_M15; break;
  case 3: time_frame_diretor = PERIOD_M30; break;
  case 4: time_frame_diretor = PERIOD_H1; break;
  case 5: time_frame_diretor = PERIOD_H4; break;
  case 6: time_frame_diretor = PERIOD_D1; break;
  case 7: time_frame_diretor = PERIOD_W1; break;
  case 8: time_frame_diretor = PERIOD_MN1; break;
  default: Print("Não entendi qual o timeframe superior que você quis dizer,"
    +" então estou desligando."); break;
  }
  
  if (time_frame_diretor != 0 && time_frame_diretor <= Period()) {
    Print("O timeframe diretor deve abranger o timeframe atual, configure-o adequadamente. "
      + "O timeframe diretor está sendo desligado.");
    time_frame_diretor = 0;
  }
  
  // Reconhecimento de padrões: 
  // gera vetores de características para mineração de dados em um arquivo
  gerar_vetores_caracteristicas = false;
  if (gerar_vetores_caracteristicas) {
    registro_ultimo_candle = Time[0];
    param_a_i = 0;
  }
  
  // análise da evolução da carteira
  // guarda o valor de depósito
  BalancoInicial = AccountBalance();
  
  return(0);
}

int deinit()
{
  // Apagar níveis de TP e SL
  // de posições ainda abertas
  for (int i=0; i<OrdersTotal(); i++)
    if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      if (!ApagarDesenho(OrderTicket()))
        Print("Não consegui apagar alguma(s) reta(s) dos níveis de TP e SL.");
  
  // e de posições já encerradas
  for (i=0; i<OrdersHistoryTotal(); i++)
    if (OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
      if (!ApagarDesenho(OrderTicket()))
        Print("Não consegui apagar alguma(s) reta(s) dos níveis de TP e SL.");

  // Indica quais foram as posições vencedoras e perdedoras com (V) e (X) no gráfico
  if (indicar_sucesso_posicoes) {
    for (i=0; i<hist_index_i; i++) {
      if (OrderSelect(hist_index[i], SELECT_BY_POS, MODE_HISTORY) && OrderMagicNumber() == MAGIC_NUM) {
        ObjectCreate("3MM-pos-" + i, OBJ_ARROW, 0, OrderOpenTime(),
          Low[iBarShift(Symbol(), 0, OrderOpenTime())] - PipsParaPreco(80));
        if (OrderProfit() >= 0) {
          ObjectSet("3MM-pos-" + i, OBJPROP_ARROWCODE, SYMBOL_CHECKSIGN);
          ObjectSet("3MM-pos-" + i, OBJPROP_COLOR, Green);
        } else if (OrderProfit() < 0) {
          ObjectSet("3MM-pos-" + i, OBJPROP_ARROWCODE, SYMBOL_STOPSIGN);
          ObjectSet("3MM-pos-" + i, OBJPROP_COLOR, Red);
        }
      }
    }
  }
  
  // Reconhecimento de padrões: 
  // gera um arquivo contendo as características extraídas
  if (gerar_vetores_caracteristicas) {
    string nome_arquivo = "3MM-caracteristicas.dat";
    fp = FileOpen(nome_arquivo, FILE_CSV | FILE_WRITE, ' ');
    if (fp != -1) {
      for (i=0; i<param_a_i; i++)
        if (OrderSelect(hist_index[i], SELECT_BY_POS, MODE_HISTORY) && OrderMagicNumber() == MAGIC_NUM)
          FileWrite(fp, DoubleToStr(param_a[i], 15));
      
      FileClose(fp);
      Print("Arquivo para data mining em files/" + nome_arquivo);
    }
  }
  
  // análise de evolução da carteira
  // gera um arquivo contendo a evolução da carteira
  if (false) {
    nome_arquivo = "evolucao_carteira.dat";
    fp = FileOpen(nome_arquivo, FILE_CSV | FILE_WRITE, ' ');
    if (fp != -1) {
      FileWrite(fp, DoubleToStr(BalancoInicial, 5));
      for (i=0; i<OrdersHistoryTotal(); i++)
        if (OrderSelect(i, SELECT_BY_POS, MODE_HISTORY) && OrderMagicNumber() == MAGIC_NUM) {
          BalancoInicial += OrderProfit();
          FileWrite(fp, DoubleToStr(BalancoInicial, 5));
        }
      
      FileClose(fp);
      Print("Arquivo para data mining em files/" + nome_arquivo);
    }
  }

  return(0);
}

int start()
{
  // Acompanha posições abertas
  if (OrdersTotal() > 0)
    AcompanhaPosicoes();
  
  // Médias móveis lenta e rápida do candle atual e anterior.
  double
    lenta_0  = iMA(Symbol(), 0, Periodo_MM_Lenta,  0, MODE_SMA, PRICE_CLOSE, 0 + shift_MMs),
    lenta_1  = iMA(Symbol(), 0, Periodo_MM_Lenta,  0, MODE_SMA, PRICE_CLOSE, 1 + shift_MMs),
    media_0  = iMA(Symbol(), 0, Periodo_MM_Media,  0, MODE_SMA, PRICE_CLOSE, 0 + shift_MMs),
    media_1  = iMA(Symbol(), 0, Periodo_MM_Media,  0, MODE_SMA, PRICE_CLOSE, 1 + shift_MMs),
    rapida_0 = iMA(Symbol(), 0, Periodo_MM_Rapida, 0, MODE_SMA, PRICE_CLOSE, 0 + shift_MMs),
    rapida_1 = iMA(Symbol(), 0, Periodo_MM_Rapida, 0, MODE_SMA, PRICE_CLOSE, 1 + shift_MMs),
    diretor_lenta_0  = iMA(Symbol(),time_frame_diretor, MM_lenta_Diretor,  0, MODE_SMA, PRICE_CLOSE, 0),
    diretor_lenta_1  = iMA(Symbol(),time_frame_diretor, MM_lenta_Diretor,  0, MODE_SMA, PRICE_CLOSE, 1),
    diretor_rapida_0 = iMA(Symbol(),time_frame_diretor, MM_rapida_Diretor, 0, MODE_SMA, PRICE_CLOSE, 0),
    diretor_rapida_1 = iMA(Symbol(),time_frame_diretor, MM_rapida_Diretor, 0, MODE_SMA, PRICE_CLOSE, 1);
  
  // Determina a tendência dada pelo timeframe diretor
  if (time_frame_diretor != 0) {
    // tendência de alta dada pelo timeframe superior
    if (diretor_lenta_0 < diretor_rapida_0 && diretor_lenta_1 > diretor_rapida_1)
      tendencia_diretor = DIRETOR_ALTA;
    
    // tendência de baixa dada pelo timeframe superior
    if (diretor_lenta_0 > diretor_rapida_0 && diretor_lenta_1 < diretor_rapida_1)
      tendencia_diretor = DIRETOR_BAIXA;
    
    // perda de tendência de alta
    if (tendencia_diretor == DIRETOR_ALTA  && diretor_rapida_0 < diretor_lenta_0)
      tendencia_diretor = DIRETOR_NOP;
    
    // perda de tendência de baixa
    if (tendencia_diretor == DIRETOR_BAIXA && diretor_rapida_0 > diretor_lenta_0)
      tendencia_diretor = DIRETOR_NOP;
  }
  
  // Checa se a trava deve ser pertinente
  if (trava_trade) {
    // destrava para uma tendência de alta
    if (lenta_0 < media_0 && lenta_0 < rapida_0 && lenta_1 < media_1 && lenta_1 < rapida_1
          && rapida_0 < media_0 && rapida_1 < media_1)
      trava_trade = false;
      
    // destrava para uma tendência de baixa
    if (lenta_0 > media_0 && lenta_0 > rapida_0 && lenta_1 > media_1 && lenta_1 > rapida_1
          && rapida_0 > media_0 && rapida_1 > media_1)
      trava_trade = false;
  }
  
  // Filtro de horário regula a abertura de posições
  if (!Aplicar_Filtro_de_Horario || 
    (Aplicar_Filtro_de_Horario && Filtro_Horario(Horario_Inicio, Horario_Fim)))
  {
    if (!trava_trade && trava_tempo != Time[0] && trava_tempo != Time[1]) {
      // Analisa tendência de alta
      if (time_frame_diretor == 0 || (time_frame_diretor != 0 && tendencia_diretor == DIRETOR_ALTA)) {
        if (media_0 > lenta_0 && rapida_0 > lenta_0 && media_1 > lenta_1 && rapida_1 > lenta_1) {
          // Cruzamento das médias móveis rápida e média
          if (rapida_1 < media_1 && rapida_0 > media_1) {
            if (!AbrePosicao(OP_BUY, Tamanho_Posicao))
              Alert("Não consegui abrir uma posição de compra.");
            else {
              trava_trade = true;
              trava_tempo = Time[0];
            }
          }
        }
      }
      
      // Analisa uma tendência de baixa
      if (time_frame_diretor == 0 || (time_frame_diretor != 0 && tendencia_diretor == DIRETOR_BAIXA)) {
        if (media_0 < lenta_0 && rapida_0 < lenta_0 && media_1 < lenta_1 && rapida_1 < lenta_1) {
          // Cruzamento das médias móveis rápida e média
          if (rapida_1 > media_1 && rapida_0 < media_0) {
            if (!AbrePosicao(OP_SELL, Tamanho_Posicao))
              Alert("Não consegui abrir uma posição de venda.");
            else {
              trava_trade = true;
              trava_tempo = Time[0];
            }
          }
        }
      }
    }
  }
  
  // Desenhar nívels de TP e SL
  if (Desenhar_TP_e_SL)
    for (int i=OrdersHistoryTotal()-2; i<OrdersHistoryTotal(); i++)
      if (OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
        ApagarDesenho(OrderTicket());
  
  // Retas de regressão
  if (Mostrar_Retas_Regressao && !( Filtro_Horario_nas_Retas
      && Aplicar_Filtro_de_Horario
      && !(Filtro_Horario(Horario_Inicio, Horario_Fim)) ))
  {
    // Reta_Regressao_{Lenta,Rapida}
    double Regressao_Rapida_a = iCustom(Symbol(), Period(), "MM_inclinacao", 
      Reta_Regressao_Rapida, Periodo_MM_Rapida, true, 0, DarkKhaki,      1, 0,
      0, 0);
    double Regressao_Media_a  = iCustom(Symbol(), Period(), "MM_inclinacao", 
      Reta_Regressao_Media,  Periodo_MM_Media,  true, 1, DarkOliveGreen, 3, 0,
      0, 0);
      
    if (Comentarios_Regressao) {
      Comment(
        "Relação entre as retas: r=" 
        + DoubleToStr(Regressao_Rapida_a / Regressao_Media_a, 3)
        + "\n"
        + "   r < 1: convergência\n"
        + "   r = 1: tendências paralelas\n"
        + "   r > 1: divergência"
      );
    }
  }
  
  // Reconhecimento de padrões:
  // registra as características estudadas tick-a-tick, conforme a função mutável ExtraiCaracteristicas.
  if (gerar_vetores_caracteristicas)
    ExtraiCaracteristicas();
  
  return(0);
}

/* Reconhecimento de padrões: extração de características */
void ExtraiCaracteristicas()
{
  // Inclinação MM de crista a vale e de vale a crista.
  if (Time[0] != registro_ultimo_candle) {
    int sinal = 5;
    double
      hist_0  = iCustom(Symbol(), 0, "DMM", 15,10,3, 0, 0),
      hist_1  = iCustom(Symbol(), 0, "DMM", 15,10,3, 0, 1),
      sinal_0 = iCustom(Symbol(), 0, "DMM", 15,10,3, 1, 0),
      sinal_1 = iCustom(Symbol(), 0, "DMM", 15,10,3, 1, 1);
    
    if ((sinal_1 > hist_1 && sinal_0 < hist_0) // vale
         ||
        (sinal_1 < hist_1 && sinal_0 > hist_0)) // crista
    {
      Registrar_double(param_a, hist_0);
      param_a_i++;
      registro_ultimo_candle = Time[0];
    }
  }
}

/* Filtro de negociações entre os horários pré-determinados. */
bool Filtro_Horario(datetime horario_inicio, datetime horario_fim)
{
  int
    hora_atual    = (TimeHour(TimeCurrent()) + GMT_do_Servidor) % 24,
    minuto_atual  = TimeMinute(TimeCurrent());
  
  if (TimeHour(horario_inicio) < TimeHour(horario_fim) 
    || (TimeHour(horario_inicio) && TimeHour(horario_fim) 
        && TimeMinute(horario_inicio) <= TimeMinute(horario_fim)))
    return ( // horario_inicio <= horario_atual <= horario_fim
      (
        TimeHour(horario_inicio) < hora_atual || 
        (TimeHour(horario_inicio) == hora_atual && TimeMinute(horario_inicio) <= minuto_atual)
      )
      &&
      (
        hora_atual < TimeHour(horario_fim) || 
        (hora_atual == TimeHour(horario_fim) && minuto_atual <= TimeMinute(horario_fim))
      )
    );
  else
    return ( // horario_atual <= horario_fim  ou  horario_inicio <= horario_atual
      (
        hora_atual < TimeHour(horario_fim) || 
        (hora_atual == TimeHour(horario_fim) && minuto_atual <= TimeMinute(horario_fim))
      )
      ||
      (
        TimeHour(horario_inicio) < hora_atual || 
        (TimeHour(horario_inicio) == hora_atual && TimeMinute(horario_inicio) <= minuto_atual)
      )
    );
}

/* Imprime uma mensagem de erro (error code) ocorrida com uma função arbitrária. */
void ImprimeMsgErro(string funcao)
{
  int erro;
  if (funcao == "OrderSend") {
    erro = GetLastError();
    switch (erro) {
    case ERR_TRADE_NOT_ALLOWED:
      Print("O expert não pode abrir posições: não é permitido negociar. Habilite essa opção no MT.");
      break;
    case ERR_LONGS_NOT_ALLOWED:
      Print("O expert não está habilitado a abrir posições de compra. Habilite essa opção no MT.");
      break;
    case ERR_SHORTS_NOT_ALLOWED:
      Print("O expert não está habilitado a abrir posições de venda. Habilite essa opção no MT.");
      break;
    case ERR_INVALID_PRICE_PARAM:
      Print("Calculei errado o preço para abrir a posição. (Avise o desenvolvedor do expert.)");
      break;
    case ERR_NOT_ENOUGH_MONEY:
      Print("Não tenho dinheiro para abrir uma posição.");
      break;
    case ERR_OFF_QUOTES:
      Print("Tentei abrir uma posição num certo preço mas a cotação mudou e o broker rejeitou a ordem.");
      break;
    default:
      if (erro > ERR_NO_ERROR && erro < ERR_TRADE_PROHIBITED_BY_FIFO)
        Print("Erro (vindo do servidor): " + ErrorDescription(erro));
      break;
    }
  }
}

/* Envia uma ordem para abertura de uma posição de tamanho `Tamanho_Posicao'. */
bool AbrePosicao(int ordem, double tamanho_posicao)
{
  if (!IsTradeAllowed() || IsTradeContextBusy())
    Print("Não consigo abrir posições: (i) você não habilitou negociações; ou (ii) Trade Context Busy");

  // registro das posições abertas
  Registrar_int_incr(hist_index, OrdersHistoryTotal(), hist_index_i);
  
  int ticket;
  if (ordem == OP_BUY) {
    ticket = OrderSend(Symbol(), OP_BUY , tamanho_posicao, Ask, 0, Ask - PipsParaPreco(SL_pips), 0,
      "", MAGIC_NUM);
    if (ticket != -1) {
      // Desenha nível de SL
      if (Desenhar_TP_e_SL)
        Desenhar(ticket, ABERTURA);
      
      // Registra a nova posição com target de TP no primeiro nível
      if (!InsereEstado(ticket, ABERTURA))
        Print("Erro ao alocar memória para os containers de estado dos níveis de TP");
      
      return (true);
    }
    
    ImprimeMsgErro("OrderSend");
  } else if (ordem == OP_SELL) {
    ticket = OrderSend(Symbol(), OP_SELL, tamanho_posicao, Bid, 0, Bid + PipsParaPreco(SL_pips), 0,
      "", MAGIC_NUM);
    if (ticket != -1) {
      // Desenha níveis de TP e SL
      if (Desenhar_TP_e_SL)
        Desenhar(ticket, ABERTURA);
      
      // Registra a nova posição com target de TP no primeiro nível
      if (!InsereEstado(ticket, ABERTURA))
        Print("Erro ao alocar memória para os containers de estado dos níveis de TP");
      
      return (true);
    }
    
    ImprimeMsgErro("OrderSend");
  }
  
  return (false);
}

/* Módulo para encerrar uma posição totalmente. */
bool EncerraPosicaoTotal()
{
  bool fechamento;
  int ticket;
  
  switch (OrderType()) {
  case OP_BUY:
    ticket = OrderTicket();
    
    // Apaga níveis de TP e SL
    if (Desenhar_TP_e_SL)
      ApagarDesenho(ticket);
    
    // Encerra posição
    fechamento = OrderClose(OrderTicket(), OrderLots(), Bid, 1);
    if (fechamento)
      if (!RemoveEstado(ticket))
        Print("Não achei a posição de ticket " + ticket 
          + " pra remover suas informações. [EncerraPosicaoTotal()]");
    
    return (fechamento);
    break;
  case OP_SELL:
    ticket = OrderTicket();
    
    // Apaga níveis de TP e SL
    if (Desenhar_TP_e_SL)
      ApagarDesenho(ticket);
    
    // Encerra posição
    fechamento = OrderClose(OrderTicket(), OrderLots(), Ask, 1);
    if (fechamento)
      if (!RemoveEstado(ticket))
        Print("Não achei a posição de ticket " + ticket
          + " pra remover suas informações. [EncerraPosicaoTotal()]");
    
    return (fechamento);
    break;
  default:
    return (true);
    break;
  }
}

/* Módulo para encerrar uma posição parcialmente, encerrando (100*p)% da posição. */
bool EncerraPosicaoParcial(double p)
{
  int ticket;
  switch (OrderType()) {
  case OP_BUY:
    ticket = OrderTicket();
    
    // Apaga níveis de TP e SL
    if (Desenhar_TP_e_SL)
      ApagarDesenho(ticket);
    
    return (OrderClose(ticket, NormalizeDouble(p * OrderLots(), 2), Bid, 1));
    break;
  case OP_SELL:
    ticket = OrderTicket();
    
    // Apaga níveis de TP e SL
    if (Desenhar_TP_e_SL)
      ApagarDesenho(ticket);
    
    return (OrderClose(OrderTicket(), NormalizeDouble(p * OrderLots(), 2), Ask, 1));
    break;
  default:
    return (true);
    break;
  }
}

/* Converte de pips para preço. */
double PipsParaPreco(int pips)
{
  return (pips * pip);
}

/* Busca o valor do pip em termos da moeda base. */
double BuscaPip()
{
  string par = StringSubstr(Symbol(), 0, 6);
  
  // pares contra Yen têm pip de 0.01
  if (StringFind(par, "JPY") != -1 || StringFind(par, "jpy") != -1)
    return (0.01);
  
  // pares contra ouro e prata têm pip de 0.01
  if (StringFind(par, "XAU") != -1 || StringFind(par, "xau") != -1 
   || StringFind(par, "XAG") != -1 || StringFind(par, "xag") != -1)
    return (0.01);

  // nota: existem pares mais exóticos que não necessariamente têm pip de 0.0001
  //       e não estão sendo contemplados aqui.
  
  // regra padrão
  if (Digits == 3 || Digits == 5)
    return (Point * 10);
  else
    return (Point);
}

/* Acompanha posições. */
void AcompanhaPosicoes()
{
  for (int i=0; i<OrdersTotal(); i++)
    if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
      if (!AcompanhaPosicaoIndividualSL3TP(OrderTicket()))
        Print("Não consegui encerrar uma posição");
    }
}

/* Acompanha uma posição individualmente, configurando níveis de TP e SL
   e a encerrando quando necessário. */
bool AcompanhaPosicaoIndividualSL3TP(int num_ticket)
{
  // Médias móveis lenta e rápida do candle atual e anterior.
  double
    lenta_0  = iMA(Symbol(), 0, Periodo_MM_Lenta,  0, MODE_SMA, PRICE_CLOSE, 0 + shift_MMs),
    lenta_1  = iMA(Symbol(), 0, Periodo_MM_Lenta,  0, MODE_SMA, PRICE_CLOSE, 1 + shift_MMs),
    media_0  = iMA(Symbol(), 0, Periodo_MM_Media,  0, MODE_SMA, PRICE_CLOSE, 0 + shift_MMs),
    media_1  = iMA(Symbol(), 0, Periodo_MM_Media,  0, MODE_SMA, PRICE_CLOSE, 1 + shift_MMs),
    rapida_0 = iMA(Symbol(), 0, Periodo_MM_Rapida, 0, MODE_SMA, PRICE_CLOSE, 0 + shift_MMs),
    rapida_1 = iMA(Symbol(), 0, Periodo_MM_Rapida, 0, MODE_SMA, PRICE_CLOSE, 1 + shift_MMs),
    diretor_lenta_0  = iMA(Symbol(),time_frame_diretor, MM_lenta_Diretor,  0, MODE_SMA, PRICE_CLOSE, 0),
    diretor_rapida_0 = iMA(Symbol(),time_frame_diretor, MM_rapida_Diretor, 0, MODE_SMA, PRICE_CLOSE, 0);

  if (!OrderSelect(num_ticket, SELECT_BY_TICKET, MODE_TRADES)) {
    Print("Não achei nenhuma posição pelo ticket " + num_ticket);
    return (false);
  }
  
  int ticket, ticket_antigo = OrderTicket();
  double preco_abertura;
  
  switch (OrderType()) {
  // Controle de uma posição comprada
  case OP_BUY:
    // Encerra posição numa mudança de tendência
    if ( (media_1 > lenta_1 && media_0 < lenta_0) || (rapida_1 > media_1 && rapida_0 < media_0) )
      return (EncerraPosicaoTotal());
    else
    // Encerra posição numa perda de tendência dada por um timeframe maior
    if (time_frame_diretor != 0 && diretor_rapida_0 < diretor_lenta_0)
      return (EncerraPosicaoTotal());
    else {
      switch (BuscaEstado(OrderTicket())) {
      case ABERTURA:
        // Checa se o primeiro nível de TP foi atingido e encerra a ordem parcialmente
        preco_abertura = OrderOpenPrice();
        if (Bid >= preco_abertura + PipsParaPreco(TP_N1_pips)) {
          if (EncerraPosicaoParcial(TP_N1_liquidar)) {
            // faz os ajustes necessários para a posição que mudou.
            ticket = NovoTicket(ticket_antigo, preco_abertura, TPN1_ATINGIDO);
            if (ticket == -1 || !OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
              Print("Não consegui selecionar a posição de ticket " + ticket 
                + " para mudar seu nível de SL.");
            else {
              // Muda o nível de SL para o preço de abertura e a cor do indicador no gráfico
              if (!OrderModify(OrderTicket(), OrderOpenPrice(), OrderOpenPrice(),
                               OrderTakeProfit(), OrderExpiration(), Green))
                Print("Não consegui mudar o SL para o preço de abertura.");
            }
          }
        }
        break;
      case TPN1_ATINGIDO:
        // Checa se o segundo nível de TP foi atingido e encerra a ordem parcialmente
        preco_abertura = OrderOpenPrice();
        if (Bid >= preco_abertura + PipsParaPreco(TP_N2_pips)) {
          if (EncerraPosicaoParcial(TP_N2_liquidar)) {
            // faz os ajustes necessários para a posição que mudou.
            ticket = NovoTicket(ticket_antigo, preco_abertura, TPN2_ATINGIDO);
            if (ticket == -1 || !OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
              Print("Não consegui selecionar a posição de ticket " + ticket 
                + " para mudar seu nível de SL.");
            else {
              if (!SL_fixo) {
                // Muda o nível de SL para o preço de abertura e a cor do indicador no gráfico
                if (!OrderModify(OrderTicket(), OrderOpenPrice(), preco_abertura +
                                 PipsParaPreco(TP_N1_pips), OrderTakeProfit(),
                                 OrderExpiration(), Lime))
                  Print("Não consegui mudar o SL para o preço de abertura.");
              }
            }
          }
        }
        break;
      case TPN2_ATINGIDO:
        // Checa se o terceiro (e último) nível de TP foi atingido e encerra a ordem totalmente
        preco_abertura = OrderOpenPrice();
        if (Bid >= preco_abertura + PipsParaPreco(TP_N3_pips)) {
          ticket = OrderTicket();
          if (!EncerraPosicaoTotal())
            Print("Não consegui remover informações da posição de ticket " + ticket);
        }
        break;
      default:
        Comment("Erro: não sei o que fazer com essa posição porque não sei o estado dela.");
        break;
      } //switch
    } //else
    break;
  // Controle de uma posição vendida
  case OP_SELL:
    // Encerra posição numa mudança de tendência
    if ( (media_1 < lenta_1 && media_0 > lenta_0) || (rapida_1 < media_1 && rapida_0 > media_0) )
      return (EncerraPosicaoTotal());
    else
    // Encerra posição numa perda de tendência dada por um timeframe maior
    if (time_frame_diretor != 0 && diretor_rapida_0 > diretor_lenta_0)
      return (EncerraPosicaoTotal());
    else {
      switch (BuscaEstado(OrderTicket())) {
      case ABERTURA:
        // Checa se o primeiro nível de TP foi atingido e encerra a posição parcialmente
        preco_abertura = OrderOpenPrice();
        if (Ask <= preco_abertura - PipsParaPreco(TP_N1_pips)) {
          if (EncerraPosicaoParcial(TP_N1_liquidar)) {
            // faz os ajustes necessários para a posição que mudou.
            ticket = NovoTicket(ticket_antigo, preco_abertura, TPN1_ATINGIDO);
            if (ticket == -1 || !OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
              Print("Não consegui selecionar a posição de ticket " + ticket 
                + " para mudar seu nível de SL.");
            else {
              // Muda o nível de SL para o preço de abertura e a cor do indicador no gráfico
              if (!OrderModify(OrderTicket(), OrderOpenPrice(), OrderOpenPrice(),
                               OrderTakeProfit(), OrderExpiration(), Green))
                Print("Não consegui mudar o SL para o preço de abertura.");
            }
          }
        }
        break;
      case TPN1_ATINGIDO:
        // Checa se o primeiro nível de TP foi atingido e encerra a posição parcialmente
        preco_abertura = OrderOpenPrice();
        if (Ask <= preco_abertura - PipsParaPreco(TP_N2_pips)) {
          if (EncerraPosicaoParcial(TP_N2_liquidar)) {
            // faz os ajustes necessários para a posição que mudou.
            ticket = NovoTicket(ticket_antigo, preco_abertura, TPN2_ATINGIDO);
            if (ticket == -1 || !OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
              Print("Não consegui selecionar a posição de ticket " + ticket 
                + " para mudar seu nível de SL.");
            else {
              if (!SL_fixo) {
                // Muda o nível de SL para o preço de abertura e a cor do indicador no gráfico
                if (!OrderModify(OrderTicket(), OrderOpenPrice(), preco_abertura -
                                 PipsParaPreco(TP_N1_pips), OrderTakeProfit(),
                                 OrderExpiration(), Lime))
                  Print("Não consegui mudar o SL para o preço de abertura.");
              }
            }
          }
        }
        break;
      case TPN2_ATINGIDO:
        // Checa se o terceiro (e último) nível de TP foi atingido e encerra a ordem totalmente
        preco_abertura = OrderOpenPrice();
        if (Ask <= preco_abertura - PipsParaPreco(TP_N3_pips)) {
          ticket = OrderTicket();
          if (!EncerraPosicaoTotal())
            Print("Não consegui remover informações da posição de ticket " + ticket);
        }
        break;
      default:
        Comment("Erro: não sei o que fazer com essa posição porque não sei o estado dela.");
        return (false);
        break;
      } //switch
    } //else
    break;
  }
  
  // nota: não usar nenhuma trecho de código envolvendo posições entre
  //       o final do último switch e o fim da função atual.
  
  return (true);
}

/* Manipulação de estados */
bool InsereEstado(int ticket, int estado)
{
  if (imprimir_estados) {
    Print("Depuração. InsereEstado(): inicio.");
    ImprimirEstados();
  }

  int tam = ArraySize(q_valido);
  if (ArrayResize(q_valido, 1 + tam) == -1) return (false);
  if (ArrayResize(q_id, 1 + tam) == -1) return (false);
  if (ArrayResize(q_estado, 1 + tam) == -1) return (false);
  
  q_valido[tam] = true;
  q_id[tam] = ticket;
  q_estado[tam] = estado;
  
  if (imprimir_estados) {
    ImprimirEstados();
    Print("Depuração. InsereEstado(): fim.");
  }
  
  return (true);
}

bool RemoveEstado(int ticket)
{
  // busca elemento a ser removido
  int remover = -1;
  for (int i=0; i<ArraySize(q_id) && remover == -1; i++)
    if (q_id[i] == ticket)
      remover = i;
  
  if (remover == -1)
    return (false);
  
  // remove da lista o elemento indexado por `remover'
  for (i=remover; i<ArraySize(q_id)-1; i++) {
    q_valido[i] = q_valido[i+1];
    q_id[i] = q_id[i+1];
    q_estado[i] = q_estado[i+1];
  }
  
  // marca o último elemento como inválido
  remover = ArraySize(q_id) - 1;
  q_valido[remover] = false;
  q_id[remover] = -1;
  q_estado[remover] = INVALIDO;
  
  // decrementa em 1 elemento os vetores
  if (!ArrayResize(q_id, remover) ||
      !ArrayResize(q_valido, remover) ||
      !ArrayResize(q_estado, remover))
  {
    Print("Erro ao remover um elemento do vetor.");
    return (false);
  }
  
  return (true);
}

/*bool AlteraEstado(int ticket, int novo_estado)
{
  int indice = -1;
  
  // Otimização na pesquisa: na grande maioria dos casos, o expert não carrega posições
  // (ou carrega muito poucas); nesse caso, é feita uma busca binária para quando existem
  // mais de 2 posições abertas.
  switch (ArraySize(q_id)) {
  case 0:
    if (q_id[0] == ticket)
      indice = 0;
    break;
  case 1:
    if (q_id[0] == ticket)
      indice = 0;
    else if (q_id[1] == ticket)
      indice = 1;
    break;
  case 2:
    if (q_id[0] == ticket)
      indice = 0;
    else if (q_id[1] == ticket)
      indice = 1;
    else if (q_id[2] == ticket)
      indice = 2;
    break;
  default:
    int
      esquerda = 0,
      meio,
      direita = ArraySize(q_id);
    
    while (indice == -1 && esquerda <= direita) {
      meio = (esquerda + direita) / 2;
      if (q_id[meio] == ticket)
        indice = meio;
      else {
        if (ticket < q_id[meio])
          direita = meio - 1;
        else
          esquerda = meio + 1;
      }
    }
    break;
  }
  
  // posição não encontrada ou posição já encerrada.
  if (indice == -1 || !q_valido[indice])
    return (false);
  
  // altera o estado de `ticket' para `novo_estado'.
  q_estado[indice] = novo_estado;
  
  return (true);
}*/

int BuscaEstado(int ticket)
{
  int indice = -1;
  
  // Otimização na pesquisa: na grande maioria dos casos, o expert não carrega posições
  // (ou carrega muito poucas); nesse caso, é feita uma busca binária para quando existem
  // mais de 2 posições abertas.
  switch (ArraySize(q_id)) {
  case 0:
    if (q_id[0] == ticket)
      indice = 0;
    break;
  case 1:
    if (q_id[0] == ticket)
      indice = 0;
    else if (q_id[1] == ticket)
      indice = 1;
    break;
  case 2:
    if (q_id[0] == ticket)
      indice = 0;
    else if (q_id[1] == ticket)
      indice = 1;
    else if (q_id[2] == ticket)
      indice = 2;
    break;
  default:
    int
      esquerda = 0,
      meio,
      direita = ArraySize(q_id);
    
    while (indice == -1 && esquerda <= direita) {
      meio = (esquerda + direita) / 2;
      if (q_id[meio] == ticket)
        indice = meio;
      else {
        if (ticket < q_id[meio])
          direita = meio - 1;
        else
          esquerda = meio + 1;
      }
    }
    break;
  }
  
  // posição não encontrada ou posição já encerrada.
  if (indice == -1 || !q_valido[indice])
    return (INVALIDO);
    
  return (q_estado[indice]);
}

/* Mostra os vetores de estados. */
void ImprimirEstados()
{
  Print("|q_id|=" + ArraySize(q_id) + " |q_estado|="
     + ArraySize(q_estado) + " |q_valido|=" + ArraySize(q_valido));
  
  string s = StringConcatenate("Q[" + ArraySize(q_id), "] = [");
  for (int i=0; i<ArraySize(q_id); i++) {
    s = StringConcatenate(s, "q_", i," = {ticket=" + q_id[i] + ",valido=");
    
    if (q_valido[i])
      s = StringConcatenate(s, "1");
    else
      s = StringConcatenate(s, "0");
    
    s = StringConcatenate(s, ",estado=");
    
    switch (q_estado[i]) {
    case ABERTURA:
      s = StringConcatenate(s, "abertura");
      break;
    case TPN1_ATINGIDO:
      s = StringConcatenate(s, "tpn1_atingido");
      break;
    case TPN2_ATINGIDO:
      s = StringConcatenate(s, "tpn2_atingido");
      break;
    case INVALIDO:
      s = StringConcatenate(s, "invalido");
      break;
    default:
      s = StringConcatenate(s, "ERRO");
      break;
    }
    
    s = StringConcatenate(s, "} ");
  }
  
  s = StringConcatenate(s, "]");
  
  return (s);
}

/* Busca uma posição aberta pelo preço. */
int OndeFoiParar(double preco)
{
  for (int i=0; i<OrdersTotal() && OrderSelect(i, SELECT_BY_POS, MODE_TRADES); i++)
    if (OrderOpenPrice() == preco)
      return (OrderTicket());
  return (-1);
}

int NovoTicket(int ticket_antigo, double preco_abertura, int q)
{
  int ticket = OndeFoiParar(preco_abertura);
  if (ticket == -1) {
    Print("Não achei nenhuma posição aberta no preço de " + preco_abertura);
    return (-1);
  }
  
  if (!RemoveEstado(ticket_antigo)) {
    Print("Não consegui remover o estado da posição associada ao ticket " + ticket_antigo);
    return (-1);
  }
  
  if (!InsereEstado(ticket, q)) {
    Print("Não consegui marcar a posição de ticket " + ticket + 
          " como uma que já alcançou um novo estado.");
    return (-1);
  }
  
  // Reajusta as retas
  if (Desenhar_TP_e_SL) {
    if (!ApagarDesenho(ticket_antigo))
      Print("Não consegui apagar as linhas de nível de TP e/ou de SL.");
    
    if (!Desenhar(ticket, q))
      Print("Não consegui desenhar os níveis de TP e SL corretamente.");
  }
  
  return (ticket);
}

/*
  Trocar em: NovoTicket, EncerraPosicao{Parcial,Total}, AbrePosicao
*/
bool Desenhar(int ticket, int q)
{
  if (OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES)) {
    double sl, preco_abertura = OrderOpenPrice();
    switch (q) {
    case ABERTURA:
      switch (OrderType()) {
      case OP_BUY:
        if (!ObjectCreate("3MM-sl-" + ticket, OBJ_HLINE, 0, 0, preco_abertura -
                          PipsParaPreco(SL_pips)))
          return (false);
        
        if (!ObjectCreate("3MM-tp1-" + ticket, OBJ_HLINE, 0, 0, preco_abertura +
                          PipsParaPreco(TP_N1_pips))) {
          ObjectDelete("3MM-tp1-" + ticket);
          return (false);
        }
        
        ObjectSet("3MM-sl-" + ticket, OBJPROP_COLOR, Red);
        ObjectSet("3MM-sl-" + ticket, OBJPROP_WIDTH, 2);
        ObjectSet("3MM-tp1-" + ticket, OBJPROP_COLOR, DarkGreen);
        
        break;
      case OP_SELL:
        if (!ObjectCreate("3MM-sl-" + ticket, OBJ_HLINE, 0, 0, preco_abertura +
                          PipsParaPreco(SL_pips)))
          return (false);
        
        if (!ObjectCreate("3MM-tp1-" + ticket, OBJ_HLINE, 0, 0, preco_abertura -
                          PipsParaPreco(TP_N1_pips)))
        {
          ObjectDelete("3MM-tp1-" + ticket);
          return (false);
        }
        
        ObjectSet("3MM-sl-" + ticket, OBJPROP_COLOR, Red);
        ObjectSet("3MM-sl-" + ticket, OBJPROP_WIDTH, 2);
        ObjectSet("3MM-tp1-" + ticket, OBJPROP_COLOR, DarkGreen);
        
        break;
      }
      break;
    case TPN1_ATINGIDO:
      switch (OrderType()) {
      case OP_BUY:
        if (!ObjectCreate("3MM-sl-" + ticket, OBJ_HLINE, 0, 0, preco_abertura))
          return (false);
        
        if (!ObjectCreate("3MM-tp2-" + ticket, OBJ_HLINE, 0, 0, preco_abertura +
                          PipsParaPreco(TP_N2_pips)))
        {
          ObjectDelete("3MM-tp2-" + ticket);
          return (false);
        }
        
        ObjectSet("3MM-sl-" + ticket, OBJPROP_COLOR, Red);
        ObjectSet("3MM-sl-" + ticket, OBJPROP_WIDTH, 1);
        ObjectSet("3MM-tp2-" + ticket, OBJPROP_COLOR, Green);
        
        break;
      case OP_SELL:
        if (!ObjectCreate("3MM-sl-" + ticket, OBJ_HLINE, 0, 0, preco_abertura))
          return (false);
        
        if (!ObjectCreate("3MM-tp2-" + ticket, OBJ_HLINE, 0, 0, preco_abertura -
                          PipsParaPreco(TP_N2_pips)))
        {
          ObjectDelete("3MM-tp2-" + ticket);
          return (false);
        }
        
        ObjectSet("3MM-sl-" + ticket, OBJPROP_COLOR, Red);
        ObjectSet("3MM-sl-" + ticket, OBJPROP_WIDTH, 1);
        ObjectSet("3MM-tp2-" + ticket, OBJPROP_COLOR, Green);
        
        break;
      }
      break;
    case TPN2_ATINGIDO:
      switch (OrderType()) {
      case OP_BUY:
        if (!SL_fixo)
          sl = preco_abertura + PipsParaPreco(TP_N1_pips);
        else
          sl = preco_abertura;
        
        if (!ObjectCreate("3MM-sl-" + ticket, OBJ_HLINE, 0, 0, sl))
          return (false);
        
        if (!ObjectCreate("3MM-tp3-" + ticket, OBJ_HLINE, 0, 0, preco_abertura +
                          PipsParaPreco(TP_N3_pips)))
        {
          ObjectDelete("3MM-tp3-" + ticket);
          return (false);
        }
        
        ObjectSet("3MM-sl-" + ticket, OBJPROP_COLOR, Maroon);
        ObjectSet("3MM-sl-" + ticket, OBJPROP_WIDTH, 1);
        ObjectSet("3MM-tp3-" + ticket, OBJPROP_COLOR, Lime);
        
        break;
      case OP_SELL:
        if (!SL_fixo)
          sl = preco_abertura - PipsParaPreco(TP_N1_pips);
        else
          sl = preco_abertura;
      
        if (!ObjectCreate("3MM-sl-" + ticket, OBJ_HLINE, 0, 0, sl))
          return (false);
        
        if (!ObjectCreate("3MM-tp3-" + ticket, OBJ_HLINE, 0, 0, preco_abertura -
                          PipsParaPreco(TP_N3_pips)))
        {
          ObjectDelete("3MM-tp3-" + ticket);
          return (false);
        }
        
        ObjectSet("3MM-sl-" + ticket, OBJPROP_COLOR, Maroon);
        ObjectSet("3MM-sl-" + ticket, OBJPROP_WIDTH, 1);
        ObjectSet("3MM-tp3-" + ticket, OBJPROP_COLOR, Lime);
        
        break;
      }
      break;
    default:
      Print("Não sei em qual estado estou.");
      return (false);
      break;
    }
  
    return (true);
  }
  
  return (false);
}

bool ApagarDesenho(int ticket)
{
  if (ObjectFind("3MM-sl-"  + ticket) != -1)
    if (!ObjectDelete("3MM-sl-"  + ticket))
      return (false);
  
  if (ObjectFind("3MM-tp1-" + ticket) != -1)
    if (!ObjectDelete("3MM-tp1-" + ticket))
      return (false);
  
  if (ObjectFind("3MM-tp2-" + ticket) != -1)
    if (!ObjectDelete("3MM-tp2-" + ticket))
      return (false);
  
  if (ObjectFind("3MM-tp3-" + ticket) != -1)
    if (!ObjectDelete("3MM-tp3-" + ticket))
      return (false);
  
  return (true);
}

/* Registro de características. */
bool Registrar_int_incr(int &vetor[], int x, int &tam)
{
  // registro das posições abertas
  if (tam == ArraySize(vetor) - 1)
    if (ArrayResize(vetor, 2 * ArraySize(vetor)) == -1) {
      Print("Aviso: não consegui redimensionar um vetor.");
      return (false);
    }
  
  vetor[tam] = x;
  tam++;
  
  return (true);
}

bool Registrar_double(double &vetor[], double x)
{
  // registro das posições abertas
  if (param_a_i == ArraySize(vetor) - 1)
    if (ArrayResize(vetor, 2 * ArraySize(vetor)) == -1) {
      Print("Aviso: não consegui redimensionar um vetor.");
      return (false);
    }
  
  vetor[param_a_i] = x;
  
  return (true);
}