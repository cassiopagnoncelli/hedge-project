//+------------------------------------------------------------------+
//|                                                  IntraCandle.mq4 |
//|                                        Cássio Jandir Pagnoncelli |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Cássio Jandir Pagnoncelli"
#property link      ""

//---- Parâmetros: início
extern int       TP            = 5;
extern int       SL            = 20;
extern double    mult          = 1.6;
extern int       step          = 100;
extern double    MargemLivre   = 8.5;
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
   Comment(AccountFreeMarginMode());
   // Saldo em tela
   if (AccountEquity() == AccountBalance())
      Comment("Liquidez: ", AccountEquity());
   else
      Comment( "Liquidez: ", AccountEquity(), "  ", 
               "Liquidez/Balanço: ", AccountEquity()/AccountBalance());

   if (OrdersTotal() == 0)
      IntraCandle();
   else
      martingale();
   
   return(0);
}

int IntraCandle() {
   if (High[0] != Low[0] && Ask == High[0]) 
      if (SL == 0)
         return (OrderSend (Symbol(), OP_SELL, Lote (), Bid, 1, 0, Bid - TP*Point));
      else
         return (OrderSend (Symbol(), OP_SELL, Lote (), Bid, 1, Bid + SL*Point, Bid - TP*Point));
   return (0);
}

double Lote() {
   double minl = MarketInfo(Symbol(), MODE_MINLOT);
   double maxl = 1;
   return (NormalizeDouble(AccountFreeMargin() * MargemLivre * (AccountLeverage()/100)/100000, 2));
}

void martingale() {
   if (!OrderSelect(OrdersTotal()-1, SELECT_BY_POS, MODE_TRADES)) return;
   if (Bid - OrderOpenPrice() < step*Point) return;
   OrderSend(Symbol(), OP_SELL , OrderLots() * mult, Bid, 1, 0, 
             NormalizeDouble(Bid - step*Point, 4));

   if (OrdersTotal() < 2) return;
   
   if (!OrderSelect(OrdersTotal()-2, SELECT_BY_POS, MODE_TRADES)) return;
   double close = OrderOpenPrice();
   if (!OrderSelect(OrdersTotal()-1, SELECT_BY_POS, MODE_TRADES)) return;
   if (close != OrderTakeProfit())
      OrderModify(OrderTicket(), OrderOpenPrice(), OrderStopLoss(), close, 0);
   
   for (int i=OrdersTotal()-2; i>=0 && OrderSelect(i, SELECT_BY_POS, MODE_TRADES); i--) 
      if (close != OrderTakeProfit())
         OrderModify(OrderTicket(), OrderOpenPrice(), OrderStopLoss(), close, 0);
}

