//+------------------------------------------------------------------+
//|                                                          3MM.mq4 |
//|                André Duarte de Novais, Cássio Jandir Pagnoncelli |
//|                                                                  |
//+------------------------------------------------------------------+

#property copyright "André Duarte de Novais, Cássio Jandir Pagnoncelli"
#property link      ""

/* TO-DO

usar MACD, RSI, Stochastic, SAR, Williams

*/

//---- Parâmetros
extern string    S1 = "-- Opções adicionais";
extern bool      AguardaCompletarBarra = true;

extern string    S2 = "-- Sinais do gráfico";
extern int       Periodo_MME_lenta     = 620;
extern int       Periodo_MME_rapida    = 200;
extern int       Periodo_MMS_sinal     = 3;

extern string    S3 = "-- Limite das ordens";
extern int       TakeProfit        = 0;
extern int       StopLoss          = 0;

extern string    S4  = "-- Proteção da conta";
extern string    S40 = "-- - Margem usada na abertura de posições (em %)";
extern int       MargemPercentual  = 5;
extern string    S41 = "-- - Liquidar saldo positivo (em %) [0, para NUNCA liquidar]";
extern double    LiquidarPositivo = 0.0;
extern string    S42 = "-- - Liquidar saldo negativo (em %) [0, para NUNCA liquidar]";
extern double    LiquidarNegativo = 0.0;

extern string    S5   = "-- Sub-estratégias";
extern string    S51  = "-- - Angulação";
extern bool      BarrarTradesNaAngulacao = false;
extern double    Angulo = 3.8;


//---- Globais
// apenas usado em 'AguardaCompletarBarra'
int       horario_ultimo_ticket;

// informações da última ordem
int       ticket = 0;
double    ultimo_lote;

// posição das MM rápida e de sinal
bool      posicao_short_anterior = false; 
double    MME_lenta_anterior;


int init() {
     // valores das MM
     MME_lenta_anterior = iMA(Symbol(), 0, Periodo_MME_lenta, 0, MODE_EMA, PRICE_TYPICAL, 0);
     double    MME_rapida = iMA(Symbol(), 0, Periodo_MME_rapida, 0, MODE_EMA, PRICE_TYPICAL, 0), 
               MMS_sinal  = iMA(Symbol(), 0, Periodo_MMS_sinal, 0, MODE_SMA, PRICE_TYPICAL, 0);
     
     // posicao das MM rapida e de sinal
     if ( MME_rapida > MMS_sinal )
          posicao_short_anterior = true;
     else 
          posicao_short_anterior = false;
     
     return (0);
}

int deinit() {
     return (0);
}

int start() {
     // liquidar balanço, independente da barra ter sido completada
     if ( (AccountEquity()/AccountBalance() > 1 + LiquidarPositivo/100) || 
          (AccountEquity()/AccountBalance() < 1 - LiquidarNegativo/100) )
          EncerraPosicao();
     
     // aguarda completar a barra
     if ( AguardaCompletarBarra )
          if ( TimeCurrent() - horario_ultimo_ticket < Period() * 60 ) 
               return (0);
          else
               horario_ultimo_ticket = MathFloor(TimeCurrent()/Period()) * Period();
     
     // valores das MM exponenciais no tick atual usando o preço típico
     double    MME_lenta  = iMA(Symbol(), 0, Periodo_MME_lenta, 0, MODE_EMA, PRICE_TYPICAL, 0),
               MME_rapida = iMA(Symbol(), 0, Periodo_MME_rapida, 0, MODE_EMA, PRICE_TYPICAL, 0), 
               MMS_sinal  = iMA(Symbol(), 0, Periodo_MMS_sinal, 0, MODE_SMA, PRICE_TYPICAL, 0);
      
     // tendência de baixa (short=true, long=false) [só opera SHORT]
     if ( MME_lenta > MME_rapida && MME_lenta > MMS_sinal ) {
          if ( !posicao_short_anterior && MMS_sinal < MME_rapida ) { // sinal de venda
               if ( AngulacaoFavoravel(OP_SELL, MME_lenta, MME_lenta_anterior) )
                    EnviaOrdemImediata(OP_SELL);
          } else if ( posicao_short_anterior && MMS_sinal >= MME_rapida ) { // encerra posicao de venda
               if ( !EncerraPosicao() )
                    Alert("Posicao de VENDA nao encerrada.");
          }
               
          // atualiza a posição das MM rapida e de sinal
          if ( MME_rapida > MMS_sinal )
               posicao_short_anterior = true;
          else 
               posicao_short_anterior = false;
     } else // tendência de alta (short=false, long=true) [só opera LONG]
     if ( MME_lenta < MME_rapida && MME_lenta < MMS_sinal ) {
          if ( posicao_short_anterior && MMS_sinal > MME_rapida ) { // sinal de compra
               if ( AngulacaoFavoravel(OP_BUY, MME_lenta, MME_lenta_anterior) )
                    EnviaOrdemImediata(OP_BUY);
          } else if ( !posicao_short_anterior && MMS_sinal < MME_rapida ) { // encerra posição de compra
               if ( !EncerraPosicao() )
                    Alert("Posicao de COMPRA não encerrada.");
          }
      
          // atualiza a posição das MM rápida e de sinal
          if ( MME_rapida > MMS_sinal )
               posicao_short_anterior = true;
          else 
               posicao_short_anterior = false;
     }
     
     // guarda a MM lenta para o proximo candlestick
     MME_lenta_anterior = iMA(Symbol(), 0, Periodo_MME_lenta, 0, MODE_EMA, PRICE_TYPICAL, 0);
     
     return (0);
}

// Define o tamanho o lote na posicao a ser aberta 
double LoteAtual() {
     return ( NormalizeDouble(
               (MathMin(AccountBalance(), AccountEquity()) * MargemPercentual * (AccountLeverage()/100)) / 100000,
               2
          )
     );
}

double Pip(int pips) {
     /*if ( MarketInfo(Symbol(), MODE_POINT) != 0 )
          pip = MarketInfo(Symbol(), MODE_POINT);*/
     
     return ( pips * 0.0001 );

}

// Encerra uma posição comprada ou vendida 
bool EncerraPosicao() {
     // a ordem já foi encerrada, possivelmente por T/P ou S/L
     if ( ticket == 0 ) 
          return ( true );
     
     // seleciona a ordem pelo ticket para encerrá-la
     // se não foi possivel selecioná-la, a ordem ja foi encerrada
     if ( !OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES) ) 
          return ( true );
     
     // encerra posição à preco de mercado
     if ( OrderType() == OP_BUY ) {
          if ( OrderClose(ticket, OrderLots(), Bid, 1) ) {
               ticket = 0;
               return (true);
          } else
               return (false);
     } else 
     if ( OrderType() == OP_SELL ) {
          if ( OrderClose(ticket, OrderLots(), Ask, 1) ) {
               ticket = 0;
               return (true);
          } else
               return (false);
     }
     
     return (false);
}

// Abre posição imediatamente 
void EnviaOrdemImediata(int cmd) {
     // abre ordem de compra
     if ( cmd == OP_BUY ) {
          if ( TakeProfit == 0 && StopLoss == 0 )
               ticket = OrderSend(Symbol(), OP_BUY, LoteAtual(), Ask, 0, 0, 0);
          else 
          if ( TakeProfit == 0 && StopLoss != 0 )
               ticket = OrderSend(Symbol(), OP_BUY, LoteAtual(), Ask, 0, Ask - Pip(StopLoss), 0);
          else
          if ( TakeProfit != 0 && StopLoss == 0 )
               ticket = OrderSend(Symbol(), OP_BUY, LoteAtual(), Ask, 0, 0, Ask + Pip(TakeProfit));
          else
          if ( TakeProfit != 0 && StopLoss != 0 )
               ticket = OrderSend(Symbol(), OP_BUY, LoteAtual(), Ask, 0, Ask - Pip(StopLoss), Ask + Pip(TakeProfit));
     } else // abre ordem de venda
     if ( cmd == OP_SELL ) {
          if ( TakeProfit == 0 && StopLoss == 0 )
               ticket = OrderSend(Symbol(), OP_SELL, LoteAtual(), Bid, 0, 0, 0);
          else 
          if ( TakeProfit == 0 && StopLoss != 0 )
               ticket = OrderSend(Symbol(), OP_SELL, LoteAtual(), Bid, 0, Bid + Pip(StopLoss), 0);
          else
          if ( TakeProfit != 0 && StopLoss == 0 )
               ticket = OrderSend(Symbol(), OP_SELL, LoteAtual(), Bid, 0, 0, Bid - Pip(TakeProfit));
          else
          if ( TakeProfit != 0 && StopLoss != 0 )
               ticket = OrderSend(Symbol(), OP_SELL, LoteAtual(), Bid, 0, Bid + Pip(StopLoss), Bid - Pip(TakeProfit));
     }
}

bool AngulacaoFavoravel(int cmd, double MME_atual, double MME_anterior) {
     // Não barra trades usando movimento angular
     if ( !BarrarTradesNaAngulacao ) 
          return (true);
     
     /*switch (cmd) {
          case OP_SELL: {
               
          } break;
          case OP_BUY: {
               
          } break;
     }*/
     
     if ( MathArctan(MathAbs(1 - MME_atual / MME_anterior)) < 3.14159 * Angulo/180 )
          return (false);
     
     return (true);
}

