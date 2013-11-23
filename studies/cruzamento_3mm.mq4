//+------------------------------------------------------------------+
//|                                               Cruzamento_3MM.mq4 |
//|                André Duarte de Novais, Cássio Jandir Pagnoncelli |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "André Duarte de Novais, Cássio Jandir Pagnoncelli"
#property link      ""

//---- input parameters
extern string    S1 = "-- Caracteristicas do Gráfico";
extern int       Periodo_MME_lenta     = 233;
extern int       Periodo_MME_rapida    = 34;
extern int       Periodo_MMS_sinal     = 5;
extern string    S2 = "-- Caracteristicas da Ordem";
extern double    LoteInicial       = 0.2;
extern int       TakeProfit        = 0;
extern int       StopLoss          = 0;
extern bool      ReinvestirCapital = true;
extern string    S3 = "-- Caracteristicas Especiais do EA";
extern bool      AguardaCompletarBarra = false;
extern bool      OtimizarCompraVenda = false;

//---- variaveis globais
bool      short = false, 
          long = false;
int       ticket = 0, 
          spread;
double    ultimo_lote, 
          pip,
          capital_inicial;

int init() {
     if ( AccountEquity() > AccountBalance() )
          capital_inicial = AccountBalance();
     else
          capital_inicial = AccountEquity();
     
     /*spread = MarketInfo(Symbol(), MODE_SPREAD);
     pip = MarketInfo(Symbol(), MODE_POINT);*/
     spread = 2;
     pip = 0.0001;

     double    MME_lenta  = iMA(Symbol(), 0, Periodo_MME_lenta, 0, MODE_EMA, PRICE_TYPICAL, 0),
               MME_rapida = iMA(Symbol(), 0, Periodo_MME_rapida, 0, MODE_EMA, PRICE_TYPICAL, 0), 
               MMS_sinal  = iMA(Symbol(), 0, Periodo_MMS_sinal, 0, MODE_SMA, PRICE_TYPICAL, 0);
     
     if ( MME_lenta > MME_rapida && MME_rapida > MMS_sinal ) {
          long = false; short = true;
     } else if ( MME_lenta < MME_rapida && MME_rapida < MMS_sinal ) {
          long = true; short = false;
     } else if ( Bid > MME_lenta ) {
          long = true; short = false;
     } else if ( Ask < MME_lenta ) {
          long = false; short = true;
     } else {
          Alert("Tente iniciar o EA no próximo candlestick ou mudar a MME lenta ", 
               "pois não foi possível ainda determinar a tendência.");
          long = true; short = false;
     }
     
     return (0);
}

int deinit() {
     Alert("");
     return (0);
}

int start() {
     // aguarda completar a barra
     if ( AguardaCompletarBarra && ((TimeCurrent()/(Period()*60)) != 0) ) 
          return (0);
     
     // valores das medias moveis no tick atual
     double    MME_lenta  = iMA(Symbol(), 0, Periodo_MME_lenta, 0, MODE_EMA, PRICE_TYPICAL, 0),
               MME_rapida = iMA(Symbol(), 0, Periodo_MME_rapida, 0, MODE_EMA, PRICE_TYPICAL, 0), 
               MMS_sinal  = iMA(Symbol(), 0, Periodo_MMS_sinal, 0, MODE_SMA, PRICE_TYPICAL, 0);
     
     // tendencia de baixa (short=true, long=false)
     if ( MME_lenta > MME_rapida && MME_rapida > MMS_sinal ) {
          if ( !short && long ) {
               ticket = InvertePosicoes(false, (MME_lenta + MME_rapida + MMS_sinal)/3);
               short = !short;
               long = !long;
          }
     } else // tendencia de alta (short=false, long=true)
     if ( MME_lenta < MME_rapida && MME_rapida < MMS_sinal ) {
          if ( short && !long ) {
               ticket = InvertePosicoes(true, (MME_lenta + MME_rapida + MMS_sinal)/3); 
               short = !short;
               long = !long;
          }
     }
     
     return (0);
}

// Define o tamanho o lote na posicao a ser aberta 
double LoteAtual() {
     if ( ReinvestirCapital ) {
          if ( AccountBalance() > AccountEquity() ) {
               return ( MathPow(AccountEquity()/capital_inicial, 2) * LoteInicial );
          } else {
               return ( MathPow(AccountBalance()/capital_inicial, 2) * LoteInicial );
          }
     } else
          return ( LoteInicial );
}

// Inverte as posicoes Long/Short e devolve o ticket da ordem 
int InvertePosicoes(bool EntraComprado, double preco) {
     // nada a inverter e um possivel erro de logica
     if ( short && long ) {
          Alert("ERRO.");
          return (0);
     } else // realiza a ordem inicial
     if ( !short && !long ) {
          Alert("Ordem Inicial.");
          ultimo_lote = LoteAtual();
          if ( EntraComprado )
               return ( EnviaOrdemImediata(OP_BUY, ultimo_lote, StopLoss, TakeProfit) );
          else
               return ( EnviaOrdemImediata(OP_SELL, ultimo_lote, StopLoss, TakeProfit) );
     } else // encerra posicao vendida e abre posicao de compra
     if ( short && !long ) { 
          EncerraPosicao(ticket, Ask, ultimo_lote); //TODO: melhorar isso
          
          ultimo_lote = LoteAtual();
          if ( !OtimizarCompraVenda ) {
               return ( EnviaOrdemImediata(OP_BUY, ultimo_lote, StopLoss, TakeProfit) );
          } else {
               return ( EnviaOrdemPendente(OP_BUYLIMIT, ultimo_lote, StopLoss, TakeProfit, preco) );
          }
     } else // encerra posicao de compra e abre posicao de venda
     if ( long && !short ) { 
          EncerraPosicao(ticket, Bid, ultimo_lote); //TODO: melhorar isso
          
          ultimo_lote = LoteAtual();
          if ( !OtimizarCompraVenda ) {
               return ( EnviaOrdemImediata(OP_SELL, ultimo_lote, StopLoss, TakeProfit) );
          } else {
               return ( EnviaOrdemPendente(OP_SELLLIMIT, ultimo_lote, StopLoss, TakeProfit, preco) );
          }
     }
     
     return (0);
}

// Encerra uma posicao comprada ou vendida 
bool EncerraPosicao(int tick, double preco, double ultimo_lote) {
     if ( tick == 0 ) 
          return (true);
     return ( OrderClose(tick, ultimo_lote, preco, 0) );
}

// Compra/Vende imediatamente 
int EnviaOrdemImediata(int cmd, double lote, int sl, int tp) {
     if ( cmd == OP_BUY ) {
               if ( TakeProfit == 0 && StopLoss == 0 )
                    return ( OrderSend(Symbol(), OP_BUY, ultimo_lote, Ask, 0, 0, 0) );
               else 
               if ( TakeProfit == 0 && StopLoss != 0 )
                    return ( OrderSend(Symbol(), OP_BUY, ultimo_lote, Ask, 0, Ask - pip*(spread + sl), 0) );
               else
               if ( TakeProfit != 0 && StopLoss == 0 )
                    return ( OrderSend(Symbol(), OP_BUY, ultimo_lote, Ask, 0, 0, Ask + pip*(spread + tp)) );
               else
               if ( TakeProfit != 0 && StopLoss != 0 )
                    return ( OrderSend(Symbol(), OP_BUY, ultimo_lote, Ask, 0, Ask - pip*(spread + sl), 
                         Ask + spread*pip + tp*pip) );          
     } else if ( cmd == OP_SELL ) {
               if ( TakeProfit == 0 && StopLoss == 0 )
                    return ( OrderSend(Symbol(), OP_SELL, lote, Bid, 0, 0, 0) );
               else 
               if ( TakeProfit == 0 && StopLoss != 0 )
                    return ( OrderSend(Symbol(), OP_SELL, lote, Bid, 0, Bid - pip*(spread + sl), 0) );
               else
               if ( TakeProfit != 0 && StopLoss == 0 )
                    return ( OrderSend(Symbol(), OP_SELL, lote, Bid, 0, 0, Bid + pip*(spread + tp)) );
               else
               if ( TakeProfit != 0 && StopLoss != 0 )
                    return ( OrderSend(Symbol(), OP_SELL, lote, Bid, 0, Bid - pip*(spread + sl), 
                         Bid + pip*(spread + tp)) );
     }
     
     return (0);
}

// Coloca ordem de compra/venda pendente
int EnviaOrdemPendente(int cmd, double lote, int sl, int tp, double preco) { // colocar vencimento nas ordens
     int vencimento = TimeCurrent() + Period() * 60 * 5; // 5 candles de vencimento
     
     if ( cmd == OP_BUYLIMIT ) {
               if ( TakeProfit == 0 && StopLoss == 0 )
                    return ( OrderSend(Symbol(), OP_BUYLIMIT, ultimo_lote, preco, 0, 0, 0, 
                         NULL, 0, vencimento) );
               else 
               if ( TakeProfit == 0 && StopLoss != 0 )
                    return ( OrderSend(Symbol(), OP_BUYLIMIT, ultimo_lote, preco, 0, preco - pip*(spread + sl), 0, 
                         NULL, 0, vencimento) );
               else
               if ( TakeProfit != 0 && StopLoss == 0 )
                    return ( OrderSend(Symbol(), OP_BUYLIMIT, ultimo_lote, preco, 0, 0, preco + pip*(spread + tp), 
                         NULL, 0, vencimento) );
               else
               if ( TakeProfit != 0 && StopLoss != 0 )
                    return ( OrderSend(Symbol(), OP_BUYLIMIT, ultimo_lote, preco, 0, preco - pip*(spread + sl), 
                         Ask + pip*(spread + tp), 
                         NULL, 0, vencimento) ); 
     } else if ( cmd == OP_SELLLIMIT ) {
               if ( TakeProfit == 0 && StopLoss == 0 )
                    return ( OrderSend(Symbol(), OP_SELLLIMIT, lote, preco, 0, 0, 0,
                         NULL, 0, vencimento) );
               else 
               if ( TakeProfit == 0 && StopLoss != 0 )
                    return ( OrderSend(Symbol(), OP_SELLLIMIT, lote, preco, 0, preco - pip*(spread + sl), 0,
                         NULL, 0, vencimento) );
               else
               if ( TakeProfit != 0 && StopLoss == 0 )
                    return ( OrderSend(Symbol(), OP_SELLLIMIT, lote, preco, 0, 0, preco + pip*(spread + tp),
                         NULL, 0, vencimento) );
               else
               if ( TakeProfit != 0 && StopLoss != 0 )
                    return ( OrderSend(Symbol(), OP_SELLLIMIT, lote, preco, 0, preco - pip*(spread + sl), 
                         Bid + pip*(spread + tp),
                         NULL, 0, vencimento) );
     }
     
     return (0);
}