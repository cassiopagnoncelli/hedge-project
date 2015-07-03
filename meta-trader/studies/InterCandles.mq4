//+------------------------------------------------------------------+
//|                                                 InterCandles.mq4 |
//|                                        Cássio Jandir Pagnoncelli |
//|                                    http://www.inf.ufpr.br/cjp07/ |
//+------------------------------------------------------------------+
#property copyright "Cássio Jandir Pagnoncelli"
#property link      "http://www.inf.ufpr.br/cjp07/"

/*
   ENTRY TRIGGERS
      on new candle of time frame if not overbought
   
   EXITS
      stop loss only
   
   MANAGEMENT OF POSITIONS
      no martingale
   
   LOT SIZE CALCULATIONS
      fixed percent of free margin
      fixed counterpips (pips to be stopped)
      
   MAIN IDEA
*/

/*
   TO-DO:
   - ...
*/

/*
   Input parameters.
*/
extern string  str_0          = "LOT SIZE CALCULATION MODE";
extern string  str_0_1        = "[0:% of free margin; 1:counter-pips]";
extern int     lot_calc_mode  = 0;
extern string  str_0_2        = "rate of free margin to open position";
extern double  fm_rate        = 0.03;
extern string  str_0_3        = "pips to be stopped (lot_calc_mode=1 only)";
extern string  str_0_3_0      = "[0:min]";
extern int     counterpips    = 0;
extern string  str_1          = "MONITOR";
extern bool    show_monitor   = true;
extern bool    info_position  = true;
extern string  str_2          = "TIME FRAME";
extern string  str_2_1        = "[0:1h; 1:2h; 2:4h; 3:6h;  4:8h;  5:12h;";
extern string  str_2_2        = " 6:1d; 7:2d; 8:5d; 9:22d; 10:264d(1y)]";
extern int     timeframe      = 6;
extern string  str_3          = "POSITION MANAGEMENT";
extern int     trailing_st    = 4;

/*
   Global vars.
*/
// error control
bool ok;
int frame_hours;


/*
   Main: init, start, and deinit.
*/
// init
int init()
{
   // no error state
   ok = true;
   
   // adjust timeframe
   switch (timeframe) {
   case 0: frame_hours = 1; break;
   case 1: frame_hours = 2; break;
   case 2: frame_hours = 4; break;
   case 3: frame_hours = 6; break;
   case 4: frame_hours = 8; break;
   case 5: frame_hours = 12; break;
   case 6: frame_hours = 24; break;
   case 7: frame_hours = 48; break;
   case 8: frame_hours = 120; break;
   case 9: frame_hours = 528; break;
   case 10: frame_hours = 6336; break;
   default: frame_hours = 24; break;
   }
   
   return(0);
}

// start
int start()
{
   intercandles();
   return(0);
}

// deinit
int deinit()
{
   if (!ok) 
   {
      Alert  ("Some error ocurred.");
      Comment("Some error ocurred.");
   }
   
   return(0);
}

/*
   Machine.
*/
void intercandles()
{
   /*
   automaton modelling intercandles in high abstraction level:
   
            | scan market | buy      | manage position | SL or TP |
   ---------+-------------+----------+-----------------+----------+
   0 active |  0 active   | 1 active |    deadlock     | deadlock |
   ---------+-------------+----------+-----------------+----------+
   1 active |   deadlock  | deadlock |    1 active     | 0 active |
   ---------+-------------+----------+-----------------+----------+
   */
   
   // no active positions at current time
   if (OrdersTotal() == 0)
      scan_symbol();
   else
      position_control();
   
   monitor();
}


/***
 *** Expert Functions.
 ***/
/*
   Scan this symbol on market to generate signal for buying.
*/
void scan_symbol()
{
   // only on time
   if (TimeCurrent() % (60 * PERIOD_H1 * frame_hours) != 0) 
      return (0);
   
   // signal
   if (Bid < Low[1] + (Low[1] + High[1]) * 0.4)
      buy();
}

/*
   Lot size calculations.
*/
// calc the size of next position switching from free margin rate and counterpips method.
double lot_size()
{
   if (lot_calc_mode == 0)
      return (NormalizeDouble(lot_fm(fm_rate), 2));
   else
      return (NormalizeDouble(lot_counterpips(counterpips), 2));
}

// 0 = min <= rate <= max = 1 is the rate of the free margin available to open new position.
double lot_fm(double rate)
{
   double min = MarketInfo(Symbol(), MODE_MINLOT);
   return (NormalizeDouble(min + (lot_max() - min) * rate/*MathMin(MathMax(rate, 0), 1)*/, Digits));
}

// the position losing `pips' (pips >= 0) is stopped out.
double lot_counterpips(int pips)
{
   return (0);
}

// proportion to next lot size and maximum lot affordable.
double lot_prop()
{
   if (lot_calc_mode == 0)
      return (lot_fm(fm_rate) / lot_max());
   else
      return (lot_counterpips(counterpips) / lot_max());
}

// size of maximum lot affordable.
double lot_max()
{
   return (AccountFreeMargin()/AccountLeverage());
   // free margin - free margin check(MINLOT) is to MINLOT size as
   // free margin                             is to MAX lot affordable
   // .°. so MAX lot affordable = free margin * MINLOT size / (free margin - free margin check(MINLOT)).
   return (AccountFreeMargin() * MarketInfo(Symbol(), MODE_MINLOT) / 
             (AccountFreeMargin() - AccountFreeMarginCheck(Symbol(), OP_BUY, MarketInfo(Symbol(), MODE_MINLOT))));
}

/*
   Orders.
*/
// buy at market price.
bool buy()
{
   bool buy_success = false;
   double 
      size = lot_size(), 
      max  = MarketInfo(Symbol(), MODE_MAXLOT),
      sl   = calc_sl();

   while (size >= max) {
      buy_success = buy_success && (OrderSend(Symbol(), OP_BUY,  max, Ask, 1, sl, 0, NULL, 0, 0, Yellow) != -1);
      size = size - max;
   }
   
   if (size >= MarketInfo(Symbol(), MODE_MINLOT)) {
      buy_success = buy_success && (OrderSend(Symbol(), OP_BUY, size, Ask, 1, sl, 0, NULL, 0, 0, Yellow) != -1);
      size = size - max;
   }
   
   ok = ok && buy_success;
   return (buy_success);
}

/*
   Position Management.
*/
// main position controller of the previously selected order.
bool position_control()
{
   if (OrderSelect(0, SELECT_BY_POS, MODE_TRADES) && OrderProfit() > 0)
      control_winning();
   
   return (true);
}

// control the profiting positions.
bool control_winning()
{
   // <import from IntraCandles4OverLots>
   if (Bid - OrderOpenPrice() < trailing_st * Point)
      return (false);
   
   /* MathMax(OrderOpenPrice() + 4 * Point, ... */
   double m = MathMax(OrderOpenPrice() + trailing_st * Point, OrderOpenPrice() + (Bid - OrderOpenPrice()) * 0.39);
   if (m + MathAbs(Bid - iSAR(Symbol(), 0, 0.02, 0.2, 1)) < Bid)
      m += MathAbs(Bid - iSAR(Symbol(), 0, 0.02, 0.2, 1)) / 10;
   
   if (iBands(Symbol(), 0, 22, 3, 0, PRICE_LOW, MODE_LOWER, 0) > OrderOpenPrice() && 
       iBands(Symbol(), 0, 22, 3, 0, PRICE_LOW, MODE_LOWER, 0) < Bid - MarketInfo(Symbol(), MODE_FREEZELEVEL)*Point)
      m = MathMax(m, iBands(Symbol(), 0, 22, 3, 0, PRICE_LOW, MODE_LOWER, 0));
   
   bool ret = true;
   int i;
   if (OrderStopLoss() == 0 || m > OrderStopLoss() && m < Bid - MarketInfo(Symbol(), MODE_FREEZELEVEL)*Point)
      for (i=0; i<OrdersTotal() && OrderSelect(i, SELECT_BY_POS, MODE_TRADES); i++)
         ret = ret && (OrderModify (OrderTicket(), OrderOpenPrice(), m, OrderTakeProfit(), OrderExpiration(), C'0x8f,0x7f,0x6f'));
   
   return (ret);
}

// calculate stop loss associated to lot size of next position.
double calc_sl()
{
   return (Ask * 0.992);
}

/*
   Monitor of this EA.
*/
void monitor()
{
   if (IsOptimization() || !show_monitor) return;
   
   // get info about positions
   string info = "";
   if (info_position) {
      // show when it will be stopped, buy price, more stops info, sl/tp targets, ...
   }
   
   // general account info
   Comment(
      StringConcatenate(AccountCompany(), "  server=", AccountServer(), "  usr=", AccountName(), "(num=", AccountCredit(), ")\n",
                        "leverage=", AccountLeverage(), " spread=", MarketInfo(Symbol(), MODE_SPREAD), "\n\n"),
      StringConcatenate("balance: ", AccountBalance(), " ", AccountCurrency(), 
                        "  equity: ", AccountEquity(), " ", AccountCurrency(),
                        "  equity/bal: ", AccountEquity()/AccountBalance(), "\n"),
      StringConcatenate("free-margin: ", AccountFreeMargin(), " ", AccountCurrency(), 
                        " (", 100 * AccountFreeMargin() / AccountEquity(),"% of equity)\n"),
      StringConcatenate("freeze-level: ", MarketInfo(Symbol(), MODE_FREEZELEVEL),
                        "  stop-level: ", MarketInfo(Symbol(), MODE_STOPLEVEL), "\n"),
      StringConcatenate("next lot size: ", lot_size(), " (", lot_prop(), "%) max-lote: ", lot_max(), "\n\n"),
      StringConcatenate("orders: ", OrdersTotal(), "\n"),
      //StringConcatenate((TimeCurrent()-OrderOpenTime())/(Period()*60), " candles\n\n"),
      info
   );
}

