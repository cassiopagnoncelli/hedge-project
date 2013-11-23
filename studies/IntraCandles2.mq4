//+------------------------------------------------------------------+
//|                                                IntraCandles2.mq4 |
//|                                        C�ssio Jandir Pagnoncelli |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "C�ssio Jandir Pagnoncelli"
#property link      ""

//---- Par�metros: in�cio
extern string    str_ctrlpos   = "-- ctrle pos";
extern double    MargemLivre   = 48;
extern int       trailing_st   = 5;

extern string    str_martin    = "-- martingale";
extern double    mult          = 9;
extern int       step          = 110;
extern int       tp_martingale = 7;
//---- Par�metros: fim

// In�cio
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
      Sinal();
   else {
      if (OrdersTotal() == 1 && OrderSelect(0, SELECT_BY_POS, MODE_TRADES)) 
         ctrlLongSL();
      martingale();
   }
   
   return(0);
}

int Sinal() {
   if (TimeCurrent() % (Period() * 60) != 0) 
      return (0);
   
   if (Bid < Low[1] + (Low[1] + High[1]) * 0.4)
      return (OrderSend(Symbol(), OP_BUY, Lote(), Ask, 1, 0, 0));
   
   return (0);
}

void martingale() {
   if (!OrderSelect(OrdersTotal()-1, SELECT_BY_POS, MODE_TRADES)) 
      return;
   
   if (OrderOpenPrice() - Bid < step*Point) 
      return;
   
   if (AccountFreeMargin() * AccountLeverage() > OrderLots() * mult * MarketInfo(Symbol(), MODE_LOTSIZE))
      OrderSend(Symbol(), OP_BUY , OrderLots() * mult, Ask, 1, 0, 0);
   
   if (OrdersTotal() < 2) 
      return;
   
   double drawdown = 0, lotes = 0;
   for (int i=0; i<OrdersTotal() && OrderSelect(i, SELECT_BY_POS, MODE_TRADES); i++) {
      drawdown += OrderLots() * OrderOpenPrice();
      lotes += OrderLots();
   }
   
   drawdown = NormalizeDouble(drawdown / lotes, Digits);
   
   drawdown += tp_martingale*Point;
   for (i=OrdersTotal()-1; i>=0 && OrderSelect(i, SELECT_BY_POS, MODE_TRADES); i--) 
      if (drawdown > Bid + MarketInfo(Symbol(), MODE_FREEZELEVEL))
         OrderModify(OrderTicket(), OrderOpenPrice(), OrderStopLoss(), drawdown, 0);
      else if (drawdown < Bid - MarketInfo(Symbol(), MODE_FREEZELEVEL))
         OrderModify(OrderTicket(), OrderOpenPrice(), drawdown, OrderTakeProfit(), 0);
      else
         OrderClose(OrderTicket(), OrderLots(), Bid, MarketInfo(Symbol(), MODE_FREEZELEVEL));
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
   
   return (NormalizeDouble(MathMin((maxl - minl)*(p / 100) + minl, MarketInfo(Symbol(), MODE_MAXLOT)), 
                           MarketInfo(Symbol(), MODE_DIGITS)));
}

bool ctrlLongSL() {
   if (Bid - OrderOpenPrice() < trailing_st * Point)
      return (false);
   
   double m = MathMax(OrderOpenPrice() + 4 * Point, OrderOpenPrice() + (Bid - OrderOpenPrice()) * 0.39);
   if (m + MathAbs(Bid - iSAR(Symbol(), 0, 0.02, 0.2, 1)) < Bid)
      m += MathAbs(Bid - iSAR(Symbol(), 0, 0.02, 0.2, 1)) / 10;
   
   if (OrderStopLoss() == 0 || m > OrderStopLoss())
      return (OrderModify (OrderTicket(), OrderOpenPrice(), m, OrderTakeProfit(), OrderExpiration()));
   
   return (false);
}

