//+------------------------------------------------------------------+
//|                                                IntraCandles3.mq4 |
//|                                        Cássio Jandir Pagnoncelli |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Cássio Jandir Pagnoncelli"
#property link      ""

//---- Parâmetros: início
extern string    str_ctrlpos   = "-- ctrle pos";
extern double    margem        = 5;
extern int       trailing_st   = 4;

extern string    str_martin    = "-- martingale";
extern double    mult          = 13;
extern int       step          = 90;
extern int       tp_martingale = 0;
//---- Parâmetros: fim


int max_martingale;
double deposito_inicial;
bool salvar = false;
datetime data_inicio;

// Início
int init() {
   max_martingale = 0;
   deposito_inicial = AccountEquity();
   data_inicio = TimeCurrent();
   return(0);
}

// Fim
int deinit() {
   string str = "";
   if (GetLastError() != 0) 
      str = StringConcatenate(str, "Houve(ram) erro(s). ");
   str = StringConcatenate(str, "max_martingale=", max_martingale, ")\r\n");
   str = StringConcatenate(str, tempo(TimeCurrent() - data_inicio));
   
   Comment(str);
   
   return(0);
}

// Loopback start
int start()
{
   Comment("liq: ", AccountEquity(), "  ", "liq/bal: ", AccountEquity()/AccountBalance());

   if (AccountEquity()/deposito_inicial > 10) 
      salvar = true;
   
   if (salvar && AccountEquity() < 2*deposito_inicial) {
      for (int i=OrdersTotal()-1; i>=0 && OrderSelect(i, SELECT_BY_POS, MODE_TRADES); i--) 
         OrderClose(OrderTicket(), OrderLots(), Bid, MarketInfo(Symbol(), MODE_FREEZELEVEL));
      return (0);
   }

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
      return (OrderSend(Symbol(), OP_BUY, Lote(margem), Ask, 1, 0, 0));
   
   return (0);
}

void martingale() {
   if (!OrderSelect(OrdersTotal()-1, SELECT_BY_POS, MODE_TRADES)) 
      return;
   
   if (OrderOpenPrice() - Bid < step*Point) 
      return;
   
   if (AccountFreeMargin() * AccountLeverage() > OrderLots() * mult * MarketInfo(Symbol(), MODE_LOTSIZE))
      OrderSend(Symbol(), OP_BUY , MathMin(OrderLots() * mult, MarketInfo(Symbol(), MODE_MAXLOT)), Ask, 1, 0, 0);
   
   max_martingale = MathMax(max_martingale, OrdersTotal());
   
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

double Lote(double p) {
   /*
      AccountFreeMargin() - accountFreeMarginCheck(MINLOT) ~ MINLOT SIZE
      AccountFreeMargin() ~ MAX lots
         ->
      MAX lots = AccountFreeMargin() * MINLOT SIZE / (AccountFreeMargin()-accountFreeMarginCheck(MINLOT))
   */
   double max = AccountFreeMargin() * MarketInfo(Symbol(), MODE_MINLOT) / 
                (AccountFreeMargin() - AccountFreeMarginCheck(Symbol(), OP_BUY, MarketInfo(Symbol(), MODE_MINLOT)));
   double min = MarketInfo(Symbol(), MODE_MINLOT);
   
   p = MathMin(MathMax(p, 0), 100); // 0 <= p <= 100
   p /= 100; // 100% == 1
   
   return (MathMin(NormalizeDouble(min + (max-min)*p, Digits), MarketInfo(Symbol(), MODE_MAXLOT)));
}

/* TIGHT: controla posicoes long vencedoras */
bool ctrlLongSL() {
   if (Bid - OrderOpenPrice() < trailing_st * Point)
      return (false);
   
   /* MathMax(OrderOpenPrice() + 4 * Point, ... */
   double m = MathMax(OrderOpenPrice() + trailing_st * Point, OrderOpenPrice() + (Bid - OrderOpenPrice()) * 0.39);
   if (m + MathAbs(Bid - iSAR(Symbol(), 0, 0.02, 0.2, 1)) < Bid)
      m += MathAbs(Bid - iSAR(Symbol(), 0, 0.02, 0.2, 1)) / 10;
   
   if (OrderStopLoss() == 0 || m > OrderStopLoss())
      return (OrderModify (OrderTicket(), OrderOpenPrice(), m, OrderTakeProfit(), OrderExpiration()));
   
   return (false);
}

string tempo(datetime t) {
   return (StringConcatenate(t/(PERIOD_D1*60), " dias"));
}