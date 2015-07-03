//+------------------------------------------------------------------+
//|                                                          ENV.mq4 |
//|                André Duarte de Novais, Cássio Jandir Pagnoncelli |
//|                                     http://www.inf.ufpr.br/cjp07 |
//+------------------------------------------------------------------+
#property copyright "André Duarte de Novais, Cássio Jandir Pagnoncelli"
#property link      "http://www.inf.ufpr.br/cjp07"
#define versao "0.0.1"

/*
   corrigir:
   - AguardarFormacaoCandle na MM do sinal.
*/

/* identificador das posições do expert */
#define MAGIC_NUM 5055

/* parâmetros. */
extern string   str0                  = "Médias Móveis";
extern int      Periodo_MM_Lenta      = 80;
extern int      Periodo_MM_Rapida     = 15;
extern bool  Aguardar_Formacao_Candle = true;
extern string   str1                  = "Retas de Regressão";
extern bool Mostrar_Retas_Regressao   = false;
extern bool Filtro_Horario_nas_Retas  = false;
extern int      Reta_Regressao_Lenta  = 10;
extern int      Reta_Regressao_Rapida = 8;
extern bool Comentarios_Regressao     = true;
extern string   str2                  = "Manejo de Risco";
extern int      SL_pips               = 130;
extern bool     SL_fixo               = false;
extern int      TP_N1_pips            = 150;
extern double   TP_N1_liquidar        = 0.1;
extern int      TP_N2_pips            = 600;
extern double   TP_N2_liquidar        = 0.5;
extern int      TP_N3_pips            = 1300;
extern bool     Desenhar_TP_e_SL      = true;
extern string   str3                  = "Position Sizing [0:fixo;1:%max]";
extern int      PositionSizing        = 1;
extern double   Tamanho_Posicao       = 1;
extern double   PerMax                = 0.1;
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

/* variáveis internas */
double pip;                         // valor do pip para o instrumento (ex.: pip do EURUSD = 0.0001)
int shift_MMs;                      // shift para aguardar a formação de candles
bool indicar_sucesso_posicoes;      // desenhar (V) e (X) sob as posições depois da execução
int hist_index[1024], hist_index_i; // registro das ordens das posições abertas (p/ desenhar (V) e (X).)
bool liberar;
double balanco_maximo;

/* variáveis de depuração */
bool imprimir_estados;              // imprime o conteúdo dos vetores de estados

/* configuração dos estados de níveis de take profit. */
bool q_valido[1];                   // status (válido ou inválido) do estado da posição
int q_id[1];                        // ticket da posição
int q_estado[1];                    // estado (abertura, TPN1, ...) da posição

/* reconhecimento de padrões */
bool gerar_vetores_caracteristicas; // habilitar/desabilitar coleta e geração de dados
int fp;                             // handler do arquivo no qual serão gravados os vetores de caract.
int caracteristicas_i;              // contador do número de vetores de características
double caracteristicas[10][1024];   // primeiro eixo dos vetores
datetime registro_ultimo_candle;    // trava temporal para barrar aquisição de característica

/* init, deinit, start. */
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
  
  // aguardar o candle se formar pra analisar o cruzamento de MMs;
  // o que se faz é analisar a MM nos dois candles anteriores.
  if (Aguardar_Formacao_Candle)
    shift_MMs = 1;
  else
    shift_MMs = 0;
  
  // Reconhecimento de padrões: 
  // gera vetores de características para mineração de dados em um arquivo
  gerar_vetores_caracteristicas = true;
  if (gerar_vetores_caracteristicas) {
    registro_ultimo_candle = Time[0];
    caracteristicas_i = 0;
  }
  
  liberar = false;
  
  balanco_maximo = AccountBalance();
  
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
        ObjectCreate("ENV-pos-" + i, OBJ_ARROW, 0, OrderOpenTime(),
          Low[iBarShift(Symbol(), 0, OrderOpenTime())] - PipsParaPreco(80));
        if (OrderProfit() >= 0) {
          ObjectSet("ENV-pos-" + i, OBJPROP_ARROWCODE, SYMBOL_CHECKSIGN);
          ObjectSet("ENV-pos-" + i, OBJPROP_COLOR, Green);
        } else if (OrderProfit() < 0) {
          ObjectSet("ENV-pos-" + i, OBJPROP_ARROWCODE, SYMBOL_STOPSIGN);
          ObjectSet("ENV-pos-" + i, OBJPROP_COLOR, Red);
        }
      }
    }
  }
  
  // Reconhecimento de padrões: 
  // gera um arquivo contendo as características extraídas
  if (gerar_vetores_caracteristicas) {
    string nome_arquivo = "ENV-testing.dat";
    fp = FileOpen(nome_arquivo, FILE_CSV | FILE_WRITE, ' ');
    if (fp != -1) {
      FileWrite(fp, "sd_L sd_R alpha_L alpha_R alpha Psar PR PL LR");
      for (i=0; i<caracteristicas_i; i++)
        if (OrderSelect(hist_index[i], SELECT_BY_POS, MODE_HISTORY) && OrderMagicNumber() == MAGIC_NUM)
          FileWrite(fp,
            DoubleToStr(caracteristicas[0][i], 15),
            DoubleToStr(caracteristicas[1][i], 15),
            DoubleToStr(caracteristicas[2][i], 15),
            DoubleToStr(caracteristicas[3][i], 15),
            DoubleToStr(caracteristicas[4][i], 15),
            DoubleToStr(caracteristicas[5][i], 15),
            DoubleToStr(caracteristicas[6][i], 15),
            DoubleToStr(caracteristicas[7][i], 15),
            DoubleToStr(caracteristicas[8][i], 15)
          );
      
      FileClose(fp);
      Print("Arquivo para data mining em tester/files/" + nome_arquivo);
    }
    
    nome_arquivo = "ENV-training.dat";
    fp = FileOpen(nome_arquivo, FILE_CSV | FILE_WRITE, ' ');
    if (fp != -1) {
      FileWrite(fp, "sd_L sd_R alpha_L alpha_R alpha Psar PR PL LR teve_lucro");
      for (i=0; i<caracteristicas_i; i++)
        if (OrderSelect(hist_index[i], SELECT_BY_POS, MODE_HISTORY) && OrderMagicNumber() == MAGIC_NUM)
          FileWrite(fp,
            OrderType()==OP_BUY,
            DoubleToStr(caracteristicas[0][i], 15),
            DoubleToStr(caracteristicas[1][i], 15),
            DoubleToStr(caracteristicas[2][i], 15),
            DoubleToStr(caracteristicas[3][i], 15),
            DoubleToStr(caracteristicas[4][i], 15),
            DoubleToStr(caracteristicas[5][i], 15),
            DoubleToStr(caracteristicas[6][i], 15),
            DoubleToStr(caracteristicas[7][i], 15),
            DoubleToStr(caracteristicas[8][i], 15),
            OrderProfit()>0
          );
      
      FileClose(fp);
      Print("Arquivo para data mining em tester/files/" + nome_arquivo);
    }
    
    nome_arquivo = "ENV-full.dat";
    fp = FileOpen(nome_arquivo, FILE_CSV | FILE_WRITE, ' ');
    if (fp != -1) {
      FileWrite(fp, "sd_L sd_R alpha_L alpha_R alpha Psar PR PL LR lucro");
      for (i=0; i<caracteristicas_i; i++)
        if (OrderSelect(hist_index[i], SELECT_BY_POS, MODE_HISTORY) && OrderMagicNumber() == MAGIC_NUM)
          FileWrite(fp,
            OrderType()==OP_BUY,
            DoubleToStr(caracteristicas[0][i], 15),
            DoubleToStr(caracteristicas[1][i], 15),
            DoubleToStr(caracteristicas[2][i], 15),
            DoubleToStr(caracteristicas[3][i], 15),
            DoubleToStr(caracteristicas[4][i], 15),
            DoubleToStr(caracteristicas[5][i], 15),
            DoubleToStr(caracteristicas[6][i], 15),
            DoubleToStr(caracteristicas[7][i], 15),
            DoubleToStr(caracteristicas[8][i], 15),
            OrderProfit()>0
          );
      
      FileClose(fp);
      Print("Arquivo para data mining em tester/files/" + nome_arquivo);
    }
  }
  
  return(0);
}

int start()
{
  // Acompanhamento de posições abertas
  if (OrdersTotal() > 0)
    AcompanhaPosicoes();
  
  double
    env_iup   = envelope(MODE_UPPER, MODE_LOWER),
    env_idown = envelope(MODE_LOWER, MODE_LOWER),
    env_up    = envelope(MODE_UPPER, MODE_UPPER),
    env_down  = envelope(MODE_LOWER, MODE_UPPER),
    mm        = iMA(Symbol(), 0, 5, 0, MODE_SMA, PRICE_CLOSE, 0);
  
  if (env_idown < mm && mm < env_iup)
    liberar = true;
  
  // Filtro de horário regula a abertura de posições
  if (!Aplicar_Filtro_de_Horario || 
    (Aplicar_Filtro_de_Horario && Filtro_Horario(Horario_Inicio, Horario_Fim)))
  {
    if (liberar)
    {
      // tendência de alta
      if (mm > env_up) {
        if (!AbrePosicao(OP_BUY, Tamanho_Posicao))
          Alert("Não consegui abrir uma posição de compra.");
        else
          liberar = false;
      }
      
      // tendência de baixa
      if (mm < env_down) {
        if (!AbrePosicao(OP_SELL, Tamanho_Posicao))
          Alert("Não consegui abrir uma posição de venda.");
        else
          liberar = false;
      }
    }
  }
  
  // Desenhar níveis de TP e SL
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
    double Regressao_Lenta_a  = iCustom(Symbol(), Period(), "MM_inclinacao", 
      Reta_Regressao_Lenta,  Periodo_MM_Lenta,  true, 1, DarkOliveGreen, 3, 0,
      0, 0);
      
    if (Comentarios_Regressao) {
      Comment(
        "Relação entre as retas: r=" 
        + DoubleToStr(Regressao_Rapida_a / Regressao_Lenta_a, 3)
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

double envelope(int modo, int borda)
{
  int periodo = 1000;
  if (modo == MODE_UPPER)
  {
    if (borda == MODE_UPPER)
      return (iEnvelopes(Symbol(), 0, periodo, MODE_SMA, 0, PRICE_CLOSE, 1.2,  MODE_UPPER, 0));
    else
      return (iEnvelopes(Symbol(), 0, periodo, MODE_SMA, 0, PRICE_CLOSE, 0.68, MODE_UPPER, 0));
  } else {
    if (borda == MODE_UPPER)
      return (iEnvelopes(Symbol(), 0, periodo, MODE_SMA, 0, PRICE_CLOSE, 1.2,  MODE_LOWER, 0));
    else
      return (iEnvelopes(Symbol(), 0, periodo, MODE_SMA, 0, PRICE_CLOSE, 0.68, MODE_LOWER, 0));
  }
}

void ExtraiCaracteristicas()
{
  return;

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
      Registrar_double(caracteristicas, hist_0);
      caracteristicas_i++;
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

/* Envia uma ordem para abertura de uma posição de tamanho `Tamanho_Posicao'. */
bool AbrePosicao(int ordem, double tamanho_posicao)
{
  if (!IsTradeAllowed() || IsTradeContextBusy())
    Print("Não consigo abrir posições: (i) você não habilitou negociações; ou (ii) Trade Context Busy");

  /* Coleta de características: início */
  double
    MML = iMA(Symbol(), 0, Periodo_MM_Lenta , 0, MODE_SMA, PRICE_CLOSE, 0),
    MMR = iMA(Symbol(), 0, Periodo_MM_Rapida, 0, MODE_SMA, PRICE_CLOSE, 0);
  
  caracteristicas[0][caracteristicas_i] = iStdDev(Symbol(), 0, Periodo_MM_Lenta, 
    0, MODE_SMA, PRICE_CLOSE, 0);
  caracteristicas[1][caracteristicas_i] = iStdDev(Symbol(), 0, Periodo_MM_Rapida, 
    0, MODE_SMA, PRICE_CLOSE, 0);
  caracteristicas[2][caracteristicas_i] = iCustom(Symbol(), Period(), "MM_inclinacao", 
    Reta_Regressao_Lenta,  Periodo_MM_Lenta,  false, 1, DarkOliveGreen, 3, 0,
    0, 0);
  caracteristicas[3][caracteristicas_i] = iCustom(Symbol(), Period(), "MM_inclinacao", 
    Reta_Regressao_Rapida, Periodo_MM_Rapida, false, 0, DarkKhaki,      1, 0,
    0, 0);
  caracteristicas[4][caracteristicas_i] = MathArctan(caracteristicas[3][caracteristicas_i]
    / caracteristicas[2][caracteristicas_i]);
  caracteristicas[5][caracteristicas_i] = MathAbs(iSAR(Symbol(), 0, 0.002, 0.01, 0) - Ask);
  caracteristicas[6][caracteristicas_i] = Ask - MMR;
  caracteristicas[7][caracteristicas_i] = Ask - MML;
  caracteristicas[8][caracteristicas_i] = MML - MMR;
  caracteristicas_i++;
  /* Coleta de características: fim. */
  
  // Registro das posições abertas
  Registrar_int_incr(hist_index, OrdersHistoryTotal(), hist_index_i);

  // Position Sizing
  double tam;
  switch (PositionSizing) {
  case 0:
    tam = tamanho_posicao;
    break;
  case 1:
    balanco_maximo = MathMax(balanco_maximo, AccountBalance());
    tam = (balanco_maximo * PerMax) / 10000;
    break;
  }

  // Envio da posição
  int ticket;
  if (ordem == OP_BUY) {
    ticket = OrderSend(Symbol(), OP_BUY , tam, Ask, 1, Ask - PipsParaPreco(SL_pips), 0,
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
  } else if (ordem == OP_SELL) {
    ticket = OrderSend(Symbol(), OP_SELL, tam, Bid, 1, Bid + PipsParaPreco(SL_pips), 0,
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

bool AcompanhaPosicaoIndividualSL3TP(int num_ticket)
{
  // Médias móveis lenta e rápida do candle atual e anterior.
  double
    lenta_0  = iMA(Symbol(), 0, Periodo_MM_Lenta,  0, MODE_SMA, PRICE_CLOSE, 0 + shift_MMs),
    lenta_1  = iMA(Symbol(), 0, Periodo_MM_Lenta,  0, MODE_SMA, PRICE_CLOSE, 1 + shift_MMs),
    rapida_0 = iMA(Symbol(), 0, Periodo_MM_Rapida, 0, MODE_SMA, PRICE_CLOSE, 0 + shift_MMs),
    rapida_1 = iMA(Symbol(), 0, Periodo_MM_Rapida, 0, MODE_SMA, PRICE_CLOSE, 1 + shift_MMs);

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
    if (false/*rapida_0 < lenta_0 && rapida_1 > lenta_1*/)
      return (EncerraPosicaoTotal());
    else {
      switch (BuscaEstado(OrderTicket())) {
      case ABERTURA:
        // Checa se o primeiro nível de TP foi atingido e encerra a ordem parcialmente
        preco_abertura = OrderOpenPrice();
        if (Bid >= preco_abertura + PipsParaPreco(TP_N1_pips)) {
          if (TP_N1_liquidar == 1) {
            if (!EncerraPosicaoTotal())
              Print("Não consegui remover informações da posição de ticket " + ticket);
          } else
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
          if (TP_N2_liquidar == 1) {
            if (!EncerraPosicaoTotal())
              Print("Não consegui remover informações da posição de ticket " + ticket);
          } else
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
    if (false/*rapida_0 > lenta_0 && rapida_1 < lenta_1*/)
      return (EncerraPosicaoTotal());
    else {
      switch (BuscaEstado(OrderTicket())) {
      case ABERTURA:
        // Checa se o primeiro nível de TP foi atingido e encerra a posição parcialmente
        preco_abertura = OrderOpenPrice();
        if (Ask <= preco_abertura - PipsParaPreco(TP_N1_pips)) {
          if (TP_N1_liquidar == 1) {
            if (!EncerraPosicaoTotal())
              Print("Não consegui remover informações da posição de ticket " + ticket);
          } else
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
          if (TP_N2_liquidar == 1) {
            if (!EncerraPosicaoTotal())
              Print("Não consegui remover informações da posição de ticket " + ticket);
          } else
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
        if (!ObjectCreate("ENV-sl-" + ticket, OBJ_HLINE, 0, 0, preco_abertura -
                          PipsParaPreco(SL_pips)))
          return (false);
        
        if (!ObjectCreate("ENV-tp1-" + ticket, OBJ_HLINE, 0, 0, preco_abertura +
                          PipsParaPreco(TP_N1_pips))) {
          ObjectDelete("ENV-tp1-" + ticket);
          return (false);
        }
        
        ObjectSet("ENV-sl-" + ticket, OBJPROP_COLOR, Red);
        ObjectSet("ENV-sl-" + ticket, OBJPROP_WIDTH, 2);
        ObjectSet("ENV-tp1-" + ticket, OBJPROP_COLOR, DarkGreen);
        
        break;
      case OP_SELL:
        if (!ObjectCreate("ENV-sl-" + ticket, OBJ_HLINE, 0, 0, preco_abertura +
                          PipsParaPreco(SL_pips)))
          return (false);
        
        if (!ObjectCreate("ENV-tp1-" + ticket, OBJ_HLINE, 0, 0, preco_abertura -
                          PipsParaPreco(TP_N1_pips)))
        {
          ObjectDelete("ENV-tp1-" + ticket);
          return (false);
        }
        
        ObjectSet("ENV-sl-" + ticket, OBJPROP_COLOR, Red);
        ObjectSet("ENV-sl-" + ticket, OBJPROP_WIDTH, 2);
        ObjectSet("ENV-tp1-" + ticket, OBJPROP_COLOR, DarkGreen);
        
        break;
      }
      break;
    case TPN1_ATINGIDO:
      switch (OrderType()) {
      case OP_BUY:
        if (!ObjectCreate("ENV-sl-" + ticket, OBJ_HLINE, 0, 0, preco_abertura))
          return (false);
        
        if (!ObjectCreate("ENV-tp2-" + ticket, OBJ_HLINE, 0, 0, preco_abertura +
                          PipsParaPreco(TP_N2_pips)))
        {
          ObjectDelete("ENV-tp2-" + ticket);
          return (false);
        }
        
        ObjectSet("ENV-sl-" + ticket, OBJPROP_COLOR, Red);
        ObjectSet("ENV-sl-" + ticket, OBJPROP_WIDTH, 1);
        ObjectSet("ENV-tp2-" + ticket, OBJPROP_COLOR, Green);
        
        break;
      case OP_SELL:
        if (!ObjectCreate("ENV-sl-" + ticket, OBJ_HLINE, 0, 0, preco_abertura))
          return (false);
        
        if (!ObjectCreate("ENV-tp2-" + ticket, OBJ_HLINE, 0, 0, preco_abertura -
                          PipsParaPreco(TP_N2_pips)))
        {
          ObjectDelete("ENV-tp2-" + ticket);
          return (false);
        }
        
        ObjectSet("ENV-sl-" + ticket, OBJPROP_COLOR, Red);
        ObjectSet("ENV-sl-" + ticket, OBJPROP_WIDTH, 1);
        ObjectSet("ENV-tp2-" + ticket, OBJPROP_COLOR, Green);
        
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
        
        if (!ObjectCreate("ENV-sl-" + ticket, OBJ_HLINE, 0, 0, sl))
          return (false);
        
        if (!ObjectCreate("ENV-tp3-" + ticket, OBJ_HLINE, 0, 0, preco_abertura +
                          PipsParaPreco(TP_N3_pips)))
        {
          ObjectDelete("ENV-tp3-" + ticket);
          return (false);
        }
        
        ObjectSet("ENV-sl-" + ticket, OBJPROP_COLOR, Maroon);
        ObjectSet("ENV-sl-" + ticket, OBJPROP_WIDTH, 1);
        ObjectSet("ENV-tp3-" + ticket, OBJPROP_COLOR, Lime);
        
        break;
      case OP_SELL:
        if (!SL_fixo)
          sl = preco_abertura - PipsParaPreco(TP_N1_pips);
        else
          sl = preco_abertura;
      
        if (!ObjectCreate("ENV-sl-" + ticket, OBJ_HLINE, 0, 0, sl))
          return (false);
        
        if (!ObjectCreate("ENV-tp3-" + ticket, OBJ_HLINE, 0, 0, preco_abertura -
                          PipsParaPreco(TP_N3_pips)))
        {
          ObjectDelete("ENV-tp3-" + ticket);
          return (false);
        }
        
        ObjectSet("ENV-sl-" + ticket, OBJPROP_COLOR, Maroon);
        ObjectSet("ENV-sl-" + ticket, OBJPROP_WIDTH, 1);
        ObjectSet("ENV-tp3-" + ticket, OBJPROP_COLOR, Lime);
        
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
  if (ObjectFind("ENV-sl-"  + ticket) != -1)
    if (!ObjectDelete("ENV-sl-"  + ticket))
      return (false);
  
  if (ObjectFind("ENV-tp1-" + ticket) != -1)
    if (!ObjectDelete("ENV-tp1-" + ticket))
      return (false);
  
  if (ObjectFind("ENV-tp2-" + ticket) != -1)
    if (!ObjectDelete("ENV-tp2-" + ticket))
      return (false);
  
  if (ObjectFind("ENV-tp3-" + ticket) != -1)
    if (!ObjectDelete("ENV-tp3-" + ticket))
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
  if (caracteristicas_i == ArraySize(vetor) - 1)
    if (ArrayResize(vetor, 2 * ArraySize(vetor)) == -1) {
      Print("Aviso: não consegui redimensionar um vetor.");
      return (false);
    }
  
  vetor[caracteristicas_i] = x;
  
  return (true);
}
