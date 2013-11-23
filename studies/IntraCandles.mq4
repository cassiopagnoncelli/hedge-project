//+------------------------------------------------------------------+
//|                                                 IntraCandles.mq4 |
//|                                        Cássio Jandir Pagnoncelli |
//|                                                 www.mexti.com.br |
//+------------------------------------------------------------------+
#property copyright "Cássio Jandir Pagnoncelli"
#property link      "www.mexti.com.br"

//---- Parâmetros: início
//-------- Lotes
extern double    MargemLivre   = 8.5;
//------------ Martingale
extern double    mult          = 1.6;
extern int       step          = 100;
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
   
   if (Bid > Close[1])
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
   
   drawdown += step*Point/10;
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
   
   return (NormalizeDouble((maxl - minl)*(p / 100) + minl, MarketInfo(Symbol(), MODE_DIGITS)));
}

bool ctrlLongSL() {
   if (Bid - OrderOpenPrice() < 5 * Point)
      return (false);
   
   double m = MathMax(OrderOpenPrice() + 5 * Point, OrderOpenPrice() + (Bid - OrderOpenPrice()) * 0.39);
   if (OrderStopLoss() == 0 || m > OrderStopLoss())
      return (OrderModify (OrderTicket(), OrderOpenPrice(), m, OrderTakeProfit(), OrderExpiration()));
   
   return (false);
}

