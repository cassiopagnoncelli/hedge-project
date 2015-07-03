//+------------------------------------------------------------------+
//|                                                       2MMSAR.mq4 |
//|                Andr� Duarte de Novais, C�ssio Jandir Pagnoncelli |
//|                                     http://www.inf.ufpr.br/cjp07 |
//+------------------------------------------------------------------+
#property copyright "Andr� Duarte de Novais, C�ssio Jandir Pagnoncelli"
#property link      "http://www.inf.ufpr.br/cjp07"
#define versao "1.0"

/* identificador das posi��es do expert */
#define MAGIC_NUM 5057

/* par�metros. */
extern string   str0                  = "Parabolic SAR";
extern double   SAR_step              = 0.02;
extern double   SAR_maximum           = 0.2;
extern string   str1                  = "M�dias M�veis";
extern int      Periodo_MM_Lenta      = 100;
extern int      Periodo_MM_Rapida     = 20;
extern string   str2                  = "Retas de Regress�o";
extern bool Mostrar_Retas_Regressao   = false;
extern bool Filtro_Horario_nas_Retas  = false;
extern int      Reta_Regressao_Lenta  = 10;
extern int      Reta_Regressao_Rapida = 8;
extern bool Comentarios_Regressao     = true;
extern string   str3                  = "Manejo de Risco";
extern double   Tam_Posicao_Natural   = 0.1;
extern double Tam_Posicao_Nao_Natural = 0.2;
extern int      SL_pips               = 50;
extern bool     SL_fixo               = false;
extern int      TP_N1_pips            = 20;
extern double   TP_N1_liquidar        = 0.5;
extern int      TP_N2_pips            = 80;
extern double   TP_N2_liquidar        = 0.5;
extern int      TP_N3_pips            = 160;
extern bool     Desenhar_TP_e_SL      = true;
extern string   str4                  = "Filtro de Hor�rio";
extern bool Aplicar_Filtro_de_Horario = false;
extern int      GMT_do_Servidor       = 3;
extern datetime Horario_Inicio        = D'1970.01.01 00:00';
extern datetime Horario_Fim           = D'1970.01.01 13:00';

/* enumera��o dos n�veis de take profit. */
#define INVALIDO -1
#define ABERTURA 0
#define TPN1_ATINGIDO 1
#define TPN2_ATINGIDO 2

/* vari�veis internas */
double pip;                         // valor do pip para o instrumento (ex.: pip do EURUSD = 0.0001)
bool trava_trade;                   // trava booleana para barrar novos trades
datetime trava_tempo;               // trava temporal para barrar novos trades
bool indicar_sucesso_posicoes;      // desenhar (V) e (X) sob as posi��es depois da execu��o
int hist_index[1024], hist_index_i; // registro das ordens das posi��es abertas (p/ desenhar (V) e (X).)

/* vari�veis de depura��o */
bool imprimir_estados;              // imprime o conte�do dos vetores de estados
int                                 // contador de posi��es abertas de venda/compra abertas por SAR
  sar_nao_natural_long,
  sar_nao_natural_short,
  sar_natural_long,
  sar_natural_short;

/* configura��o dos estados de n�veis de take profit. */
bool q_valido[1];                   // status (v�lido ou inv�lido) do estado da posi��o
int q_id[1];                        // ticket da posi��o
int q_estado[1];                    // estado (abertura, TPN1, ...) da posi��o

/* reconhecimento de padr�es */
bool gerar_vetores_caracteristicas; // habilitar/desabilitar coleta e gera��o de dados
int fp;                             // handler do arquivo no qual ser�o gravados os vetores de caract.
int param_a_i;                      // contador do n�mero de vetores de caracter�sticas
double param_a[1024];               // primeiro eixo dos vetores
datetime registro_ultimo_candle;    // trava temporal para barrar aquisi��o de caracter�stica

/*
  init, deinit, start.
*/
int init()
{
  // otimiza��o para remover desenhos de n�veis de TP e SL
  // em modo de otimiza��o e modo n�o visual (em que n�o h� gr�fico)
  HideTestIndicators(false);
  if (IsOptimization() || !IsVisualMode())
    Desenhar_TP_e_SL = false;
  
  // indicar succeso das posi��es
  hist_index_i = 0;                 // contador de posi��es abertas
  if (IsTesting() && !IsOptimization())
    indicar_sucesso_posicoes = true;
  else
    indicar_sucesso_posicoes = false;
  
  // depura��o
  imprimir_estados = false;
  sar_nao_natural_short = 0;
  sar_nao_natural_long = 0;
  sar_natural_short = 0;
  sar_natural_long = 0;
  
  // busca valor do pip em termos da moeda base
  pip = BuscaPip();
  Print("Valor do pip configurado para " + DoubleToStr(pip, 1 - (MathLog(pip)/MathLog(10)))
    + " em termos da moeda base.");
  
  // trava pra n�o fazer negocia��es � desabilitada
  trava_trade = false;
  trava_tempo = D'1970.01.01 00:00';
  
  // contador de posi��es abertas
  hist_index_i = 0;
  
  // Reconhecimento de padr�es: 
  // gera vetores de caracter�sticas para minera��o de dados em um arquivo
  gerar_vetores_caracteristicas = false;
  if (gerar_vetores_caracteristicas) {
    registro_ultimo_candle = Time[0];
    param_a_i = 0;
  }
  
  return(0);
}

int deinit()
{
  // Apagar n�veis de TP e SL
  for (int i=0; i<OrdersTotal(); i++)
    if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      if (!ApagarDesenho(OrderTicket()))
        Print("N�o consegui apagar alguma(s) reta(s) dos n�veis de TP e SL.");

  for (i=0; i<OrdersHistoryTotal(); i++)
    if (OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
      if (!ApagarDesenho(OrderTicket()))
        Print("N�o consegui apagar alguma(s) reta(s) dos n�veis de TP e SL.");
  
  // Indica quais foram as posi��es vencedoras e perdedoras com (V) e (X) no gr�fico
  if (indicar_sucesso_posicoes) {
    for (i=0; i<hist_index_i; i++) {
      if (OrderSelect(hist_index[i], SELECT_BY_POS, MODE_HISTORY) && OrderMagicNumber() == MAGIC_NUM) {
        ObjectCreate("2MMSAR-pos-" + i, OBJ_ARROW, 0, OrderOpenTime(),
          Low[iBarShift(Symbol(), 0, OrderOpenTime())] - PipsParaPreco(80));
        if (OrderProfit() >= 0) {
          ObjectSet("2MMSAR-pos-" + i, OBJPROP_ARROWCODE, SYMBOL_CHECKSIGN);
          ObjectSet("2MMSAR-pos-" + i, OBJPROP_COLOR, Green);
        } else if (OrderProfit() < 0) {
          ObjectSet("2MMSAR-pos-" + i, OBJPROP_ARROWCODE, SYMBOL_STOPSIGN);
          ObjectSet("2MMSAR-pos-" + i, OBJPROP_COLOR, Red);
        }
      }
    }
  }
  
  // Gera os vetores de caracter�sticas em um arquivo
  if (gerar_vetores_caracteristicas) {
    string nome_arquivo = "2MMSAR-caracteristicas.dat";
    fp = FileOpen(nome_arquivo, FILE_CSV | FILE_WRITE, ' ');
    if (fp != -1) {
      for (i=0; i<param_a_i; i++)
        if (OrderSelect(hist_index[i], SELECT_BY_POS, MODE_HISTORY) && OrderMagicNumber() == MAGIC_NUM)
          FileWrite(fp, DoubleToStr(param_a[i], 15));
      
      FileClose(fp);
      Print("Arquivo para data mining em tester/files/" + nome_arquivo);
    }
  }

  Print("Posi��es de compra: " + sar_natural_long + " por SAR natural e "
                  + sar_nao_natural_long  + " por SAR n�o natural");
  Print("Posi��es de venda: "  + sar_natural_short + "por SAR natural e "
                  + sar_nao_natural_short + " por SAR n�o natural");
  Print("Total: " + DoubleToStr(sar_natural_long + sar_natural_short, 0) + " por SAR natural e "
                  + DoubleToStr(sar_nao_natural_long + sar_nao_natural_short, 0)
                  + " por SAR n�o natural");

  return(0);
}

int start()
{
  // Acompanha posi��es abertas
  if (OrdersTotal() > 0)
    AcompanhaPosicoes();
  
  // Libera trade caso o SAR tenha mudado de dire��o
  double
    sar_0 = iSAR(Symbol(), 0, SAR_step, SAR_maximum, 0),
    sar_1 = iSAR(Symbol(), 0, SAR_step, SAR_maximum, 1);
  
  if (trava_trade) {
    if ((sar_1 < Low[1] && sar_0 > High[0]) || (sar_1 > High[1] && sar_0 < Low[0]))
      trava_trade = false;
  }
  
  // Filtro de hor�rio regula a abertura de posi��es
  if (!Aplicar_Filtro_de_Horario || 
    (Aplicar_Filtro_de_Horario && Filtro_Horario(Horario_Inicio, Horario_Fim)))
  {
    // M�dias m�veis lenta e r�pida do candle atual e anterior.
    double
      lenta_0  = iMA(Symbol(), 0, Periodo_MM_Lenta,  0, MODE_SMA, PRICE_CLOSE, 0),
      rapida_0 = iMA(Symbol(), 0, Periodo_MM_Rapida, 0, MODE_SMA, PRICE_CLOSE, 0);
  
    // Mant�m no m�ximo uma posi��o aberta
    if (!trava_trade && trava_tempo != Time[0]) {
      // tend�ncia de alta
      if (rapida_0 > lenta_0) {
        // Natural
        if (sar_1 > High[1] && sar_0 < Low[0])
        {
          if (!AbrePosicao(OP_BUY, Tam_Posicao_Natural))
            Alert("N�o consegui abrir uma posi��o de compra.");
          else {
            trava_trade = true;
            trava_tempo = Time[0];
            sar_natural_long++;
          }
        }
        
        // N�o-natural
        if (sar_1 > High[1] && sar_0 > High[0] && sar_1 <= sar_0)
        {
          if (!AbrePosicao(OP_BUY, Tam_Posicao_Natural))
            Alert("N�o consegui abrir uma posi��o de compra.");
          else {
            trava_trade = true;
            trava_tempo = Time[0];
            sar_nao_natural_long++;
          }
        }
      }
      
      // tend�ncia de baixa
      if (rapida_0 < lenta_0) {
        // Natural
        if (sar_1 < Bid && sar_0 > Bid)
        {
          if (!AbrePosicao(OP_SELL, Tam_Posicao_Natural))
            Alert("N�o consegui abrir uma posi��o de venda.");
          else {
            trava_trade = true;
            trava_tempo = Time[0];
            sar_natural_short++;
          }
        }
        
        // N�o-natural
        if (sar_1 < Low[1] && sar_0 < Low[0] && sar_1 >= sar_0)
        {
          if (!AbrePosicao(OP_SELL, Tam_Posicao_Nao_Natural))
            Alert("N�o consegui abrir uma posi��o de venda.");
          else {
            trava_trade = true;
            trava_tempo = Time[0];
            sar_nao_natural_short++;
          }
        }
      }
    }
  }
  
  // Desenhar n�veis de TP e SL
  if (Desenhar_TP_e_SL)
    for (int i=OrdersHistoryTotal()-2; i<OrdersHistoryTotal(); i++)
      if (OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
        ApagarDesenho(OrderTicket());
  
  // Retas de regress�o
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
        "Rela��o entre as retas: r=" 
        + DoubleToStr(Regressao_Rapida_a / Regressao_Lenta_a, 3)
        + "\n"
        + "   r < 1: converg�ncia\n"
        + "   r = 1: tend�ncias paralelas\n"
        + "   r > 1: diverg�ncia"
      );
    }
  }
  
  // Reconhecimento de padr�es:
  // registra as caracter�sticas estudadas tick-a-tick, conforme a fun��o mut�vel ExtraiCaracteristicas.
  if (gerar_vetores_caracteristicas)
    ExtraiCaracteristicas();
    
  return(0);
}

void ExtraiCaracteristicas()
{
  // Inclina��o MM de crista a vale e de vale a crista.
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

/* Filtro de negocia��es entre os hor�rios pr�-determinados. */
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

/* Envia uma ordem para abertura de uma posi��o de tamanho `Tamanho_Posicao'. */
bool AbrePosicao(int ordem, double tamanho_posicao)
{
  if (!IsTradeAllowed() || IsTradeContextBusy())
    Print("N�o consigo abrir posi��es: (i) voc� n�o habilitou negocia��es; ou (ii) Trade Context Busy");

  // registro das posi��es abertas
  Registrar_int_incr(hist_index, OrdersHistoryTotal(), hist_index_i);
  
  int ticket;
  if (ordem == OP_BUY) {
    ticket = OrderSend(Symbol(), OP_BUY , tamanho_posicao, Ask, 1, Ask - PipsParaPreco(SL_pips), 0,
      "", MAGIC_NUM);
    if (ticket != -1) {
      // Desenha n�vel de SL
      if (Desenhar_TP_e_SL)
        Desenhar(ticket, ABERTURA);
      
      // Registra a nova posi��o com target de TP no primeiro n�vel
      if (!InsereEstado(ticket, ABERTURA))
        Print("Erro ao alocar mem�ria para os containers de estado dos n�veis de TP");
      
      return (true);
    }
  } else if (ordem == OP_SELL) {
    ticket = OrderSend(Symbol(), OP_SELL, tamanho_posicao, Bid, 1, Bid + PipsParaPreco(SL_pips), 0,
      "", MAGIC_NUM);
    if (ticket != -1) {
      // Desenha n�veis de TP e SL
      if (Desenhar_TP_e_SL)
        Desenhar(ticket, ABERTURA);
      
      // Registra a nova posi��o com target de TP no primeiro n�vel
      if (!InsereEstado(ticket, ABERTURA))
        Print("Erro ao alocar mem�ria para os containers de estado dos n�veis de TP");
      
      return (true);
    }
  }
  
  return (false);
}

/* M�dulo para encerrar uma posi��o totalmente. */
bool EncerraPosicaoTotal()
{
  bool fechamento;
  int ticket;
  
  switch (OrderType()) {
  case OP_BUY:
    ticket = OrderTicket();
    
    // Apaga n�veis de TP e SL
    if (Desenhar_TP_e_SL)
      ApagarDesenho(ticket);
    
    // Encerra posi��o
    fechamento = OrderClose(OrderTicket(), OrderLots(), Bid, 1);
    if (fechamento)
      if (!RemoveEstado(ticket))
        Print("N�o achei a posi��o de ticket " + ticket 
          + " pra remover suas informa��es. [EncerraPosicaoTotal()]");
    
    return (fechamento);
    break;
  case OP_SELL:
    ticket = OrderTicket();
    
    // Apaga n�veis de TP e SL
    if (Desenhar_TP_e_SL)
      ApagarDesenho(ticket);
    
    // Encerra posi��o
    fechamento = OrderClose(OrderTicket(), OrderLots(), Ask, 1);
    if (fechamento)
      if (!RemoveEstado(ticket))
        Print("N�o achei a posi��o de ticket " + ticket
          + " pra remover suas informa��es. [EncerraPosicaoTotal()]");
    
    return (fechamento);
    break;
  default:
    return (true);
    break;
  }
}

/* M�dulo para encerrar uma posi��o parcialmente, encerrando (100*p)% da posi��o. */
bool EncerraPosicaoParcial(double p)
{
  int ticket;
  switch (OrderType()) {
  case OP_BUY:
    ticket = OrderTicket();
    
    // Apaga n�veis de TP e SL
    if (Desenhar_TP_e_SL)
      ApagarDesenho(ticket);
    
    return (OrderClose(ticket, NormalizeDouble(p * OrderLots(), 2), Bid, 1));
    break;
  case OP_SELL:
    ticket = OrderTicket();
    
    // Apaga n�veis de TP e SL
    if (Desenhar_TP_e_SL)
      ApagarDesenho(ticket);
    
    return (OrderClose(OrderTicket(), NormalizeDouble(p * OrderLots(), 2), Ask, 1));
    break;
  default:
    return (true);
    break;
  }
}

/* Converte de pips para pre�o. */
double PipsParaPreco(int pips)
{
  return (pips * pip);
}

/* Busca o valor do pip em termos da moeda base. */
double BuscaPip()
{
  string par = StringSubstr(Symbol(), 0, 6);
  
  // pares contra Yen t�m pip de 0.01
  if (StringFind(par, "JPY") != -1 || StringFind(par, "jpy") != -1)
    return (0.01);
  
  // pares contra ouro e prata t�m pip de 0.01
  if (StringFind(par, "XAU") != -1 || StringFind(par, "xau") != -1 
   || StringFind(par, "XAG") != -1 || StringFind(par, "xag") != -1)
    return (0.01);

  // nota: existem pares mais ex�ticos que n�o necessariamente t�m pip de 0.0001
  //       e n�o est�o sendo contemplados aqui.
  
  // regra padr�o
  if (Digits == 3 || Digits == 5)
    return (Point * 10);
  else
    return (Point);
}

/* Acompanha posi��es. */
void AcompanhaPosicoes()
{
  for (int i=0; i<OrdersTotal(); i++)
    if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
      if (!AcompanhaPosicaoIndividualSL3TP(OrderTicket()))
        Print("N�o consegui encerrar uma posi��o");
    }
}

bool AcompanhaPosicaoIndividualSL3TP(int num_ticket)
{
  // M�dias m�veis lenta e r�pida do candle atual e anterior.
  double
    lenta_0  = iMA(Symbol(), 0, Periodo_MM_Lenta,  0, MODE_SMA, PRICE_CLOSE, 0),
    lenta_1  = iMA(Symbol(), 0, Periodo_MM_Lenta,  0, MODE_SMA, PRICE_CLOSE, 1),
    rapida_0 = iMA(Symbol(), 0, Periodo_MM_Rapida, 0, MODE_SMA, PRICE_CLOSE, 0),
    rapida_1 = iMA(Symbol(), 0, Periodo_MM_Rapida, 0, MODE_SMA, PRICE_CLOSE, 1);

  if (!OrderSelect(num_ticket, SELECT_BY_TICKET, MODE_TRADES)) {
    Print("N�o achei nenhuma posi��o pelo ticket " + num_ticket);
    return (false);
  }
  
  int ticket, ticket_antigo = OrderTicket();
  double preco_abertura;
  
  switch (OrderType()) {
  // Controle de uma posi��o comprada
  case OP_BUY:
    // Encerra posi��o numa mudan�a de tend�ncia
    if (rapida_0 < lenta_0 && rapida_1 > lenta_1)
      return (EncerraPosicaoTotal());
    else {
      switch (BuscaEstado(OrderTicket())) {
      case ABERTURA:
        // Checa se o primeiro n�vel de TP foi atingido e encerra a ordem parcialmente
        preco_abertura = OrderOpenPrice();
        if (Bid >= preco_abertura + PipsParaPreco(TP_N1_pips)) {
          if (EncerraPosicaoParcial(TP_N1_liquidar)) {
            // faz os ajustes necess�rios para a posi��o que mudou.
            ticket = NovoTicket(ticket_antigo, preco_abertura, TPN1_ATINGIDO);
            if (ticket == -1 || !OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
              Print("N�o consegui selecionar a posi��o de ticket " + ticket 
                + " para mudar seu n�vel de SL.");
            else {
              // Muda o n�vel de SL para o pre�o de abertura e a cor do indicador no gr�fico
              if (!OrderModify(OrderTicket(), OrderOpenPrice(), OrderOpenPrice(),
                               OrderTakeProfit(), OrderExpiration(), Green))
                Print("N�o consegui mudar o SL para o pre�o de abertura.");
            }
          }
        }
        break;
      case TPN1_ATINGIDO:
        // Checa se o segundo n�vel de TP foi atingido e encerra a ordem parcialmente
        preco_abertura = OrderOpenPrice();
        if (Bid >= preco_abertura + PipsParaPreco(TP_N2_pips)) {
          if (EncerraPosicaoParcial(TP_N2_liquidar)) {
            // faz os ajustes necess�rios para a posi��o que mudou.
            ticket = NovoTicket(ticket_antigo, preco_abertura, TPN2_ATINGIDO);
            if (ticket == -1 || !OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
              Print("N�o consegui selecionar a posi��o de ticket " + ticket 
                + " para mudar seu n�vel de SL.");
            else {
              if (!SL_fixo) {
                // Muda o n�vel de SL para o pre�o de abertura e a cor do indicador no gr�fico
                if (!OrderModify(OrderTicket(), OrderOpenPrice(), preco_abertura +
                                 PipsParaPreco(TP_N1_pips), OrderTakeProfit(),
                                 OrderExpiration(), Lime))
                  Print("N�o consegui mudar o SL para o pre�o de abertura.");
              }
            }
          }
        }
        break;
      case TPN2_ATINGIDO:
        // Checa se o terceiro (e �ltimo) n�vel de TP foi atingido e encerra a ordem totalmente
        preco_abertura = OrderOpenPrice();
        if (Bid >= preco_abertura + PipsParaPreco(TP_N3_pips)) {
          ticket = OrderTicket();
          if (!EncerraPosicaoTotal())
            Print("N�o consegui remover informa��es da posi��o de ticket " + ticket);
        }
        break;
      default:
        Comment("Erro: n�o sei o que fazer com essa posi��o porque n�o sei o estado dela.");
        break;
      } //switch
      break;
    } //else
  // Controle de uma posi��o vendida
  case OP_SELL:
    // Encerra posi��o numa mudan�a de tend�ncia
    if (rapida_0 > lenta_0 && rapida_1 < lenta_1)
      return (EncerraPosicaoTotal());
    else {
      switch (BuscaEstado(OrderTicket())) {
      case ABERTURA:
        // Checa se o primeiro n�vel de TP foi atingido e encerra a posi��o parcialmente
        preco_abertura = OrderOpenPrice();
        if (Ask <= preco_abertura - PipsParaPreco(TP_N1_pips)) {
          if (EncerraPosicaoParcial(TP_N1_liquidar)) {
            // faz os ajustes necess�rios para a posi��o que mudou.
            ticket = NovoTicket(ticket_antigo, preco_abertura, TPN1_ATINGIDO);
            if (ticket == -1 || !OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
              Print("N�o consegui selecionar a posi��o de ticket " + ticket 
                + " para mudar seu n�vel de SL.");
            else {
              // Muda o n�vel de SL para o pre�o de abertura e a cor do indicador no gr�fico
              if (!OrderModify(OrderTicket(), OrderOpenPrice(), OrderOpenPrice(),
                               OrderTakeProfit(), OrderExpiration(), Green))
                Print("N�o consegui mudar o SL para o pre�o de abertura.");
            }
          }
        }
        break;
      case TPN1_ATINGIDO:
        // Checa se o primeiro n�vel de TP foi atingido e encerra a posi��o parcialmente
        preco_abertura = OrderOpenPrice();
        if (Ask <= preco_abertura - PipsParaPreco(TP_N2_pips)) {
          if (EncerraPosicaoParcial(TP_N2_liquidar)) {
            // faz os ajustes necess�rios para a posi��o que mudou.
            ticket = NovoTicket(ticket_antigo, preco_abertura, TPN2_ATINGIDO);
            if (ticket == -1 || !OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
              Print("N�o consegui selecionar a posi��o de ticket " + ticket 
                + " para mudar seu n�vel de SL.");
            else {
              if (!SL_fixo) {
                // Muda o n�vel de SL para o pre�o de abertura e a cor do indicador no gr�fico
                if (!OrderModify(OrderTicket(), OrderOpenPrice(), preco_abertura -
                                 PipsParaPreco(TP_N1_pips), OrderTakeProfit(),
                                 OrderExpiration(), Lime))
                  Print("N�o consegui mudar o SL para o pre�o de abertura.");
              }
            }
          }
        }
        break;
      case TPN2_ATINGIDO:
        // Checa se o terceiro (e �ltimo) n�vel de TP foi atingido e encerra a ordem totalmente
        preco_abertura = OrderOpenPrice();
        if (Ask <= preco_abertura - PipsParaPreco(TP_N3_pips)) {
          ticket = OrderTicket();
          if (!EncerraPosicaoTotal())
            Print("N�o consegui remover informa��es da posi��o de ticket " + ticket);
        }
        break;
      default:
        Comment("Erro: n�o sei o que fazer com essa posi��o porque n�o sei o estado dela.");
        return (false);
        break;
      } //switch
    } //else
    break;
  }
  
  // nota: n�o usar nenhuma trecho de c�digo envolvendo posi��es entre
  //       o final do �ltimo switch e o fim da fun��o atual.
  
  return (true);
}

/* Manipula��o de estados */
bool InsereEstado(int ticket, int estado)
{
  if (imprimir_estados) {
    Print("Depura��o. InsereEstado(): inicio.");
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
    Print("Depura��o. InsereEstado(): fim.");
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
  
  // marca o �ltimo elemento como inv�lido
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
  
  // Otimiza��o na pesquisa: na grande maioria dos casos, o expert n�o carrega posi��es
  // (ou carrega muito poucas); nesse caso, � feita uma busca bin�ria para quando existem
  // mais de 2 posi��es abertas.
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
  
  // posi��o n�o encontrada ou posi��o j� encerrada.
  if (indice == -1 || !q_valido[indice])
    return (false);
  
  // altera o estado de `ticket' para `novo_estado'.
  q_estado[indice] = novo_estado;
  
  return (true);
}*/

int BuscaEstado(int ticket)
{
  int indice = -1;
  
  // Otimiza��o na pesquisa: na grande maioria dos casos, o expert n�o carrega posi��es
  // (ou carrega muito poucas); nesse caso, � feita uma busca bin�ria para quando existem
  // mais de 2 posi��es abertas.
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
  
  // posi��o n�o encontrada ou posi��o j� encerrada.
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

/* Busca uma posi��o aberta pelo pre�o. */
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
    Print("N�o achei nenhuma posi��o aberta no pre�o de " + preco_abertura);
    return (-1);
  }
  
  if (!RemoveEstado(ticket_antigo)) {
    Print("N�o consegui remover o estado da posi��o associada ao ticket " + ticket_antigo);
    return (-1);
  }
  
  if (!InsereEstado(ticket, q)) {
    Print("N�o consegui marcar a posi��o de ticket " + ticket + 
          " como uma que j� alcan�ou um novo estado.");
    return (-1);
  }
  
  // Reajusta as retas
  if (Desenhar_TP_e_SL) {
    if (!ApagarDesenho(ticket_antigo))
      Print("N�o consegui apagar as linhas de n�vel de TP e/ou de SL.");
    
    if (!Desenhar(ticket, q))
      Print("N�o consegui desenhar os n�veis de TP e SL corretamente.");
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
        if (!ObjectCreate("2MMSAR-sl-" + ticket, OBJ_HLINE, 0, 0, preco_abertura -
                          PipsParaPreco(SL_pips)))
          return (false);
        
        if (!ObjectCreate("2MMSAR-tp1-" + ticket, OBJ_HLINE, 0, 0, preco_abertura +
                          PipsParaPreco(TP_N1_pips))) {
          ObjectDelete("2MMSAR-tp1-" + ticket);
          return (false);
        }
        
        ObjectSet("2MMSAR-sl-" + ticket, OBJPROP_COLOR, Red);
        ObjectSet("2MMSAR-sl-" + ticket, OBJPROP_WIDTH, 2);
        ObjectSet("2MMSAR-tp1-" + ticket, OBJPROP_COLOR, DarkGreen);
        
        break;
      case OP_SELL:
        if (!ObjectCreate("2MMSAR-sl-" + ticket, OBJ_HLINE, 0, 0, preco_abertura +
                          PipsParaPreco(SL_pips)))
          return (false);
        
        if (!ObjectCreate("2MMSAR-tp1-" + ticket, OBJ_HLINE, 0, 0, preco_abertura -
                          PipsParaPreco(TP_N1_pips)))
        {
          ObjectDelete("2MMSAR-tp1-" + ticket);
          return (false);
        }
        
        ObjectSet("2MMSAR-sl-" + ticket, OBJPROP_COLOR, Red);
        ObjectSet("2MMSAR-sl-" + ticket, OBJPROP_WIDTH, 2);
        ObjectSet("2MMSAR-tp1-" + ticket, OBJPROP_COLOR, DarkGreen);
        
        break;
      }
      break;
    case TPN1_ATINGIDO:
      switch (OrderType()) {
      case OP_BUY:
        if (!ObjectCreate("2MMSAR-sl-" + ticket, OBJ_HLINE, 0, 0, preco_abertura))
          return (false);
        
        if (!ObjectCreate("2MMSAR-tp2-" + ticket, OBJ_HLINE, 0, 0, preco_abertura +
                          PipsParaPreco(TP_N2_pips)))
        {
          ObjectDelete("2MMSAR-tp2-" + ticket);
          return (false);
        }
        
        ObjectSet("2MMSAR-sl-" + ticket, OBJPROP_COLOR, Red);
        ObjectSet("2MMSAR-sl-" + ticket, OBJPROP_WIDTH, 1);
        ObjectSet("2MMSAR-tp2-" + ticket, OBJPROP_COLOR, Green);
        
        break;
      case OP_SELL:
        if (!ObjectCreate("2MMSAR-sl-" + ticket, OBJ_HLINE, 0, 0, preco_abertura))
          return (false);
        
        if (!ObjectCreate("2MMSAR-tp2-" + ticket, OBJ_HLINE, 0, 0, preco_abertura -
                          PipsParaPreco(TP_N2_pips)))
        {
          ObjectDelete("2MMSAR-tp2-" + ticket);
          return (false);
        }
        
        ObjectSet("2MMSAR-sl-" + ticket, OBJPROP_COLOR, Red);
        ObjectSet("2MMSAR-sl-" + ticket, OBJPROP_WIDTH, 1);
        ObjectSet("2MMSAR-tp2-" + ticket, OBJPROP_COLOR, Green);
        
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
        
        if (!ObjectCreate("2MMSAR-sl-" + ticket, OBJ_HLINE, 0, 0, sl))
          return (false);
        
        if (!ObjectCreate("2MMSAR-tp3-" + ticket, OBJ_HLINE, 0, 0, preco_abertura +
                          PipsParaPreco(TP_N3_pips)))
        {
          ObjectDelete("2MMSAR-tp3-" + ticket);
          return (false);
        }
        
        ObjectSet("2MMSAR-sl-" + ticket, OBJPROP_COLOR, Maroon);
        ObjectSet("2MMSAR-sl-" + ticket, OBJPROP_WIDTH, 1);
        ObjectSet("2MMSAR-tp3-" + ticket, OBJPROP_COLOR, Lime);
        
        break;
      case OP_SELL:
        if (!SL_fixo)
          sl = preco_abertura - PipsParaPreco(TP_N1_pips);
        else
          sl = preco_abertura;
      
        if (!ObjectCreate("2MMSAR-sl-" + ticket, OBJ_HLINE, 0, 0, sl))
          return (false);
        
        if (!ObjectCreate("2MMSAR-tp3-" + ticket, OBJ_HLINE, 0, 0, preco_abertura -
                          PipsParaPreco(TP_N3_pips)))
        {
          ObjectDelete("2MMSAR-tp3-" + ticket);
          return (false);
        }
        
        ObjectSet("2MMSAR-sl-" + ticket, OBJPROP_COLOR, Maroon);
        ObjectSet("2MMSAR-sl-" + ticket, OBJPROP_WIDTH, 1);
        ObjectSet("2MMSAR-tp3-" + ticket, OBJPROP_COLOR, Lime);
        
        break;
      }
      break;
    default:
      Print("N�o sei em qual estado estou.");
      return (false);
      break;
    }
  
    return (true);
  }
  
  return (false);
}

bool ApagarDesenho(int ticket)
{
  if (ObjectFind("2MMSAR-sl-"  + ticket) != -1)
    if (!ObjectDelete("2MMSAR-sl-"  + ticket))
      return (false);
  
  if (ObjectFind("2MMSAR-tp1-" + ticket) != -1)
    if (!ObjectDelete("2MMSAR-tp1-" + ticket))
      return (false);
  
  if (ObjectFind("2MMSAR-tp2-" + ticket) != -1)
    if (!ObjectDelete("2MMSAR-tp2-" + ticket))
      return (false);
  
  if (ObjectFind("2MMSAR-tp3-" + ticket) != -1)
    if (!ObjectDelete("2MMSAR-tp3-" + ticket))
      return (false);
  
  return (true);
}

/* Registro de caracter�sticas. */
bool Registrar_int_incr(int &vetor[], int x, int &tam)
{
  // registro das posi��es abertas
  if (tam == ArraySize(vetor) - 1)
    if (ArrayResize(vetor, 2 * ArraySize(vetor)) == -1) {
      Print("Aviso: n�o consegui redimensionar um vetor.");
      return (false);
    }
  
  vetor[tam] = x;
  tam++;
  
  return (true);
}

bool Registrar_double(double &vetor[], double x)
{
  // registro das posi��es abertas
  if (param_a_i == ArraySize(vetor) - 1)
    if (ArrayResize(vetor, 2 * ArraySize(vetor)) == -1) {
      Print("Aviso: n�o consegui redimensionar um vetor.");
      return (false);
    }
  
  vetor[param_a_i] = x;
  
  return (true);
}
