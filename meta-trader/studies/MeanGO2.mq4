#property copyright "Cássio Jandir Pagnoncelli"

/*
   MeanGO versão SHORT
*/

//---- Parâmetros: início
extern string    str0          = "-- bandas de bollinger";
extern int       sd            = 3;
extern int       per           = 35;

extern string    str1          = "-- tamanho dos lotes";
extern double    MargemLivre   = 8.5;

extern string    str2          = "-- controle de posições";
extern double    hei           = 0.61;
extern int       start         = 150;

extern string    str3          = "-- martingale";
extern double    mult          = 1.6;
extern int       step          = 100;
extern int       tp_martingale = 10;
//---- Parâmetros: fim

// Início
int init() {
   return(0);
}

// Fim
int deinit() {
   if (GetLastError() != 0) 
      Comment("Houve(ram) erro(s).");
   
   return(0);
}

// Loopback start
int start()
{
   Comment("liq: ", AccountEquity(), "  ", "liq/bal: ", AccountEquity()/AccountBalance());

   if (OrdersTotal() == 0)
      MeanGO(per, sd);
   else {
      if (OrdersTotal() == 1 && OrderSelect(0, SELECT_BY_POS, MODE_TRADES)) 
         ctrlShortSL();
      martingale();
   }
   
   return(0);
}

int MeanGO(int bbPer, int bbsd) {
   if (Ask > iBands (Symbol(), 0, bbPer, bbsd, 0, PRICE_HIGH, MODE_UPPER, 0)) 
      return (OrderSend (Symbol(), OP_SELL, Lote (), Bid, 1, 0, 0));
   return (0);
}

double Lote() {
   if (AccountFreeMarginMode() != 1 || AccountStopoutMode() != 0) 
      return (0);
   
   double p = MargemLivre;
   if (p < 0) p = 0;
   if (p > 100) p = 100;
   
   double minl = MarketInfo(Symbol(), MODE_MINLOT);
   double maxl = AccountLeverage() * AccountFreeMargin() / 
              (MarketInfo(Symbol(), MODE_TICKVALUE) * MarketInfo(Symbol(), MODE_LOTSIZE));
   
   return (MathMin(NormalizeDouble((maxl - minl)*(p / 100) + minl, MarketInfo(Symbol(), MODE_DIGITS)), 
                   MarketInfo(Symbol(), MODE_MAXLOT) - MarketInfo(Symbol(), MODE_LOTSTEP)));
}

void martingale() {
   if (!OrderSelect(OrdersTotal()-1, SELECT_BY_POS, MODE_TRADES)) 
      return;
   
   if (Bid - OrderOpenPrice() < step*Point) 
      return;
   
   if (AccountFreeMargin() * AccountLeverage() > OrderLots() * mult * MarketInfo(Symbol(), MODE_LOTSIZE))
      OrderSend(Symbol(), OP_SELL , OrderLots() * mult, Bid, 1, 0, NormalizeDouble(Bid - step*Point, 4));
   
   if (OrdersTotal() < 2) 
      return;
      
   if (!OrderSelect(OrdersTotal() - 2, SELECT_BY_POS, MODE_TRADES)) 
      return;
   
   if (!OrderSelect(OrdersTotal() - 1, SELECT_BY_POS, MODE_TRADES)) 
      return;
   
   double drawdown = 0, lotes = 0;
   for (int i=0; i<OrdersTotal() && OrderSelect(i, SELECT_BY_POS, MODE_TRADES); i++) {
      drawdown += OrderLots() * OrderOpenPrice();
      lotes += OrderLots();
   }
   
   drawdown = NormalizeDouble(drawdown / lotes, Digits);
   
   drawdown -= tp_martingale * Point;
   for (i=OrdersTotal()-1; i>=0 && OrderSelect(i, SELECT_BY_POS, MODE_TRADES); i--) 
      if (drawdown > Bid + MarketInfo(Symbol(), MODE_FREEZELEVEL))
         OrderModify(OrderTicket(), OrderOpenPrice(), drawdown, OrderTakeProfit(), 0);
      else if (drawdown < Bid - MarketInfo(Symbol(), MODE_FREEZELEVEL))
         OrderModify(OrderTicket(), OrderOpenPrice(), OrderStopLoss(), drawdown, 0);
      else
         OrderClose(OrderTicket(), OrderLots(), Bid, MarketInfo(Symbol(), MODE_FREEZELEVEL));
}

bool ctrlShortSL() {
   double sl = Bid + iEnvelopes(Symbol(), 0, 55, MODE_LWMA, 0, PRICE_HIGH, 0.2, MODE_UPPER, 0)
                   - iEnvelopes(Symbol(), 0, 55, MODE_LWMA, 0, PRICE_LOW, 0.2, MODE_LOWER, 0);
   
   sl = NormalizeDouble(OrderOpenPrice() - (OrderOpenPrice() - sl) * hei, Digits);
   
   if (OrderStopLoss() != 0 && OrderStopLoss() <= sl) {
      if (iSAR(Symbol(), 0, 0.015, 0.025, 0) > Bid)
         sl -= iSAR(Symbol(), 0, 0.015, 0.025, 0) - Bid;
      if (OrderStopLoss() != 0 && OrderStopLoss() <= sl)
         return (false);
   }
   
   if (sl < OrderOpenPrice() - start*Point)
      return (OrderModify (OrderTicket(), OrderOpenPrice(), sl, OrderTakeProfit(), OrderExpiration()));
   
   return (false);
}

