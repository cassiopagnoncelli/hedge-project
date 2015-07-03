//+------------------------------------------------------------------+
//|                                                          MM3.mq4 |
//|                                        Cássio Jandir Pagnoncelli |
//|                                          www.inf.ufpr.br/~cjp07/ |
//+------------------------------------------------------------------+
#property copyright "Cássio Jandir Pagnoncelli"
#property link      "www.inf.ufpr.br/~cjp07/"

extern int       MME_LENTA    = 140;
extern int       MME_RAPIDA   = 21;
extern int       MMS_SINAL    = 1;
extern int       TAKE_PROFIT  = 110;
extern int       STOP_LOSS    = 180;
extern double    LOTE         = 0.01;

double mme_l, mme_r, mms_s, pip = 0.00001;
int ticket;
bool short, long;

int init() {
     ticket = 0;
     short = false;
     long = false;
     return (0);
}

int deinit() {
     return (0);
}

int start() {
     mme_l = iMA(Symbol(), 0, MME_LENTA, 0, MODE_EMA, PRICE_TYPICAL, 0);
     mme_r = iMA(Symbol(), 0, MME_RAPIDA, 0, MODE_EMA, PRICE_TYPICAL, 0);
     mms_s = iMA(Symbol(), 0, MMS_SINAL, 0, MODE_SMA, PRICE_TYPICAL, 0);
     
     if ( mme_l > mme_r && mme_r > mms_s && !short ) {
          if ( long ) { 
               OrderClose(ticket, LOTE, Bid, 0);
               long = false;
          }
          
          ticket = OrderSend(Symbol(), OP_SELL, LOTE, Bid, 0, Ask + STOP_LOSS * pip, Ask - TAKE_PROFIT * pip);
          short = true;
     } else if ( mme_l < mme_r && mme_r < mms_s && !long ) {
          if ( short ) {
               OrderClose(ticket, LOTE, Ask, 3);
               short = false;
          }
          
          ticket = OrderSend(Symbol(), OP_BUY, LOTE, Ask, 0, Bid - STOP_LOSS * pip, Bid + TAKE_PROFIT * pip);
          long = true;
     }
     
     return (0);
}
