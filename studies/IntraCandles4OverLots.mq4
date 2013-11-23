//+------------------------------------------------------------------+
//|                                        IntraCandles4OverLots.mq4 |
//|                                                           Cássio |
//|                                                                  |
//+------------------------------------------------------------------+

/*
   int drawdown_pips(double lote, double drawdown$);
   double drawdown$(double lote, int drawdown_pips);
   double lote(int drawdown_pips, double drawdown$);
   
   double lote_martingale1(mult, step1, drawdown_step1); // tamanho do lote inicial
   double lote_martingale2(mult, step1, drawdown_step1, step2, drawdown_step2); // tamanho do lote inicial
   
   double contra_pips(drawdown_pips); // tamanho do lote
*/

/* OTIMIZAÇÕES
   margem   trailing_st mult  step  tp_martingale
   0.06     10          10    50    0
   0.02     10          11    35    0
   0.05     14          11    33    0
 */
//---- Parâmetros: início
extern string    str_ctrlpos   = "-- ctrle pos";
extern double    margem        = 0.02;
extern int       trailing_st   = 60;

extern string    str_martin    = "-- martingale";
extern double    mult          = 11;
extern int       step          = 35;
extern int       tp_martingale = 0;
//---- Parâmetros: fim


int max_martingale;
double deposito_inicial;
bool salvar = false, stop_ea = false;
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
   tela();
   return(0);
}

// Loopback start
int start()
{
   tela();

   if (salvar || AccountEquity()/deposito_inicial > 10) {
      salvar = true;
      
      if (AccountEquity() < 2*deposito_inicial) {
         for (int i=OrdersTotal()-1; i>=0 && OrderSelect(i, SELECT_BY_POS, MODE_TRADES); i--) 
            OrderClose(OrderTicket(), OrderLots(), Bid, MarketInfo(Symbol(), MODE_FREEZELEVEL));
         stop_ea = true;
      }
      
      if (stop_ea)
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
      return (OrderSend(Symbol(), OP_BUY, lote(margem), Ask, 1, 0, 0));
   
   return (0);
}

void martingale() {
   if (!OrderSelect(OrdersTotal()-1, SELECT_BY_POS, MODE_TRADES)) 
      return;
   
   if (OrderOpenPrice() - Bid < step*Point) 
      return;
   
   if (AccountFreeMargin() * AccountLeverage() > OrderLots() * mult * MarketInfo(Symbol(), MODE_LOTSIZE))
      buy(OrderLots() * mult);
   
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
      if (drawdown > Bid + MarketInfo(Symbol(), MODE_FREEZELEVEL)*Point)
         OrderModify(OrderTicket(), OrderOpenPrice(), OrderStopLoss(), drawdown, 0);
      else if (drawdown < Bid - MarketInfo(Symbol(), MODE_FREEZELEVEL)*Point)
         OrderModify(OrderTicket(), OrderOpenPrice(), drawdown, OrderTakeProfit(), 0);
      else
         OrderClose(OrderTicket(), OrderLots(), Bid, MarketInfo(Symbol(), MODE_FREEZELEVEL));
}

double lote(double p) {
   /*
      AccountFreeMargin()-AccountFreeMarginCheck(MINLOT) ~ MINLOT SIZE
      AccountFreeMargin() ~ MAX lots
         ->
      MAX lots = AccountFreeMargin() * MINLOT SIZE / (AccountFreeMargin()-accountFreeMarginCheck(MINLOT))
   */
   double max = AccountFreeMargin() * MarketInfo(Symbol(), MODE_MINLOT) / 
                (AccountFreeMargin() - AccountFreeMarginCheck(Symbol(), OP_BUY, MarketInfo(Symbol(), MODE_MINLOT)));
   double min = MarketInfo(Symbol(), MODE_MINLOT);
   
   p = MathMin(MathMax(p, 0), 1); // 0 <= p <= 100
   
   return (NormalizeDouble(min + (max-min)*p, Digits));
}

/* TIGHT: controla posicoes long vencedoras */
bool ctrlLongSL() {
   if (Bid - OrderOpenPrice() < trailing_st * Point)
      return (false);
   
   /* MathMax(OrderOpenPrice() + 4 * Point, ... */
   double m = MathMax(OrderOpenPrice() + trailing_st * Point, OrderOpenPrice() + (Bid - OrderOpenPrice()) * 0.39);
   if (m + MathAbs(Bid - iSAR(Symbol(), 0, 0.02, 0.2, 1)) < Bid)
      m += MathAbs(Bid - iSAR(Symbol(), 0, 0.02, 0.2, 1)) / 10;
   
   if (iBands(Symbol(), 0, 22, 3, 0, PRICE_LOW, MODE_LOWER, 0) > OrderOpenPrice() && 
       iBands(Symbol(), 0, 22, 3, 0, PRICE_LOW, MODE_LOWER, 0) < Bid - MarketInfo(Symbol(), MODE_FREEZELEVEL)*Point)
      m = MathMax(m, iBands(Symbol(), 0, 22, 3, 0, PRICE_LOW, MODE_LOWER, 0));
   
   
   if (OrderStopLoss() == 0 || m > OrderStopLoss() && m < Bid - MarketInfo(Symbol(), MODE_FREEZELEVEL)*Point)
      return (OrderModify (OrderTicket(), OrderOpenPrice(), m, OrderTakeProfit(), OrderExpiration(), C'0x8f,0x7f,0x6f'));
   
   return (false);
}

bool buy(double vol) {
   RefreshRates();
   if (vol <= MarketInfo(Symbol(), MODE_MAXLOT))
      return (OrderSend(Symbol(), OP_BUY , NormalizeDouble(vol, 2), Ask, 1, 0, 0, NULL, 0, 0, Yellow));
   
   if (vol >= MarketInfo(Symbol(), MODE_MINLOT)) {
      bool r = OrderSend(Symbol(), OP_BUY, MarketInfo(Symbol(), MODE_MAXLOT), Ask, 1, 0, 0, NULL, 0, 0, Yellow);
      return (r && buy(vol - MarketInfo(Symbol(), MODE_MAXLOT)));
   }
   
   return (false);
}

void tela() {
   string s;
   if (OrdersTotal() == 0)
      s = "";
   else if (OrdersTotal() == 1) {
      s = StringConcatenate(
         StringConcatenate("#1 buy ", OrderLots(), " ", Symbol(), " at ", OrderOpenPrice()), 
         StringConcatenate("\nstopout: ", AccountMargin()*AccountStopoutLevel()/100, " ", AccountCurrency(), " (", // em deposit currency?
            100*(AccountMargin()*AccountStopoutLevel()/100)/AccountEquity(), "% of equity)"),
         StringConcatenate("\nprofit-crude: ", pip_price(OrderLots()) * ((Bid-OrderOpenPrice())/Point), " ", AccountCurrency(), "  ",
                           "profit-liq: ", AccountProfit(), " ", AccountCurrency(), "  ",
                           "swaps: ", AccountProfit()-pip_price(OrderLots()) * ((Bid-OrderOpenPrice())/Point), " (", OrderSwap(), ")"),
         StringConcatenate("\n", (Bid-OrderOpenPrice())/Point, " pips", "  ",
                           "1 pip = ", lote(margem)),
         StringConcatenate("\nequity/margin: ", 100*AccountEquity()/AccountMargin(), "%"),
         StringConcatenate("\n", (TimeCurrent()-OrderOpenTime())/(Period()*60), " candles (", 
            (TimeCurrent()-OrderOpenTime())/(PERIOD_D1*60), " dia(s))"));
   } else {
      s = "";
   }
   
   Comment(
      StringConcatenate(AccountCompany(), "  server=", AccountServer(), "  usr=", AccountName(), "(num=", AccountCredit(), ")\n"),
      
      StringConcatenate("\nbal: ", AccountBalance(), " ", AccountCurrency()),
      StringConcatenate("\nequity: ", AccountEquity(), " ", AccountCurrency()),
      StringConcatenate("\nequity/bal: ", AccountEquity()/AccountBalance(), " (min=,max=)\n"),
      
      StringConcatenate("\nleverage=", AccountLeverage(), " spread=", MarketInfo(Symbol(), MODE_SPREAD)), 
      StringConcatenate("\nmargin: ", AccountMargin()," ", AccountCurrency(), " (", 100*AccountMargin()/AccountEquity(), "% of equity)"),
      StringConcatenate("\nfree-margin: ",AccountFreeMargin()," ",AccountCurrency()," (",100*AccountFreeMargin()/AccountEquity(),"% of equity)"),
      
      StringConcatenate("\n\nprox-lote: ", lote(margem), " (", lote(margem)/lote(1), "%) max-lote: ", lote(1)),
      StringConcatenate("\nfreeze-level: ", MarketInfo(Symbol(), MODE_FREEZELEVEL), "  stop-level: ", MarketInfo(Symbol(), MODE_STOPLEVEL)),

      StringConcatenate("\n\n", s)
          );
}

double pip_price(double lot_size) {
   /*
      1 lot ~ MODE_TICKVALUE (preço do pip por lote em moeda de depósito)
      k lot ~ pip_price
   */
   double pip_price = lot_size * MarketInfo(Symbol(), MODE_TICKVALUE);
   return (pip_price);
}