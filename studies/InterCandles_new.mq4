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
   - lot_max()
*/

#include <stderror.mqh>
#include <stdlib.mqh>

/*
   Input parameters.
*/
extern string  str_0          = "LOT SIZE CALCULATION MODE";
extern string  str_0_1        = "rate of free margin to open position";
extern double  fm_rate        = 0.035;
extern string  str_1          = "MONITOR";
extern bool    show_monitor   = false;
extern string  str_2          = "TIME FRAME";
extern string  str_2_1        = "[0:1h; 1:2h; 2:4h; 3:6h;  4:8h;  5:12h;";
extern string  str_2_2        = " 6:1d; 7:2d; 8:5d; 9:22d; 10:264d(1y)]";
extern int     timeframe      = 2;
extern string  str_3          = "POSITION MANAGEMENT";
extern string  str_3_1        = "trailing start (factor of spread)";
extern double  trailing_factr = 1.3;
extern string  str_3_2        = "stop loss";
extern double  sl_prop        = 0.99;

/*
   Global vars.
*/
// error control
int num_errors;

// frame selected
int frame_hours;

// initial deposit
double initial_deposit;


/*
   Main: init, start, and deinit.
*/
// init
int init()
{
   // no error state
   num_errors = 0;
   
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
   
   initial_deposit = AccountEquity();
   
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
   if (num_errors > 0) 
      Comment("Some error ocurred. (", num_errors, " errors occurred.)");
   
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
   
   if (show_monitor && !IsOptimization())
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
   if (TimeCurrent() % (60 * PERIOD_H1 * frame_hours) != 0) //shift
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
   return (NormalizeDouble(lot_fm(fm_rate), 2));
}

// 0 = min <= rate <= max = 1 is the rate of the free margin available to open new position.
double lot_fm(double rate)
{
   double min  = MarketInfo(Symbol(), MODE_MINLOT);
   double size = min + (lot_max() - min) * rate;
   
   return (MathFloor(size / min) * min);
}

// proportion to next lot size and maximum lot affordable.
double lot_prop()
{
   return (lot_fm(fm_rate) / lot_max());
}

// size of maximum lot affordable.
double lot_max()
{
   //return (NormalizeDouble(AccountFreeMargin()/AccountLeverage(), 1));
   
   // free margin - free margin check(MINLOT) is to MINLOT size the same way as
   // free margin                             is to MAX lot affordable
   // .°. so MAX lot affordable = free margin * MINLOT size / (free margin - free margin check(MINLOT)).
   double size = AccountFreeMargin() * MarketInfo(Symbol(), MODE_MINLOT) / 
             (AccountFreeMargin() - AccountFreeMarginCheck(Symbol(), OP_BUY, MarketInfo(Symbol(), MODE_MINLOT)));

   return (MathFloor(size / MarketInfo(Symbol(), MODE_MINLOT)) * MarketInfo(Symbol(), MODE_MINLOT));
}

/*
   Orders.
*/
// buy at market price.
bool buy()
{
   bool buy_success = true;
   double 
      size = lot_size(), 
      max  = MarketInfo(Symbol(), MODE_MAXLOT),
      sl   = calc_sl();

   while (size >= max) {
      buy_success = buy_success && (OrderSend(Symbol(), OP_BUY,  max, Ask, 1, sl, 0, NULL, 0, 0, Yellow) != -1);
      size = size - max;
   }
   
   if (size >= MarketInfo(Symbol(), MODE_MINLOT)) {
      if (OrderSend(Symbol(), OP_BUY, size, Ask, 1, sl, 0, NULL, 0, 0, Yellow) == -1) {
         buy_success = false;
         Print("--------------------------> ", ErrorDescription(GetLastError()), " #debug: size=", size, " sl=", sl);
         
      }
   }
   
   if (!buy_success) 
      num_errors++;

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
void control_winning()
{

   if (Bid < OrderOpenPrice() + trailing_factr * MarketInfo(Symbol(), MODE_SPREAD) * Point)
      return (true);

   double m = MathMax(OrderOpenPrice() + trailing_factr * MarketInfo(Symbol(), MODE_SPREAD) * Point, 
                      OrderOpenPrice() + (Bid - OrderOpenPrice()) * 0.39);
   if (m + MathAbs(Bid - iSAR(Symbol(), 0, 0.02, 0.2, 1)) < Bid)
      m += MathAbs(Bid - iSAR(Symbol(), 0, 0.02, 0.2, 1)) / 10;
   
   if (iBands(Symbol(), 0, 22, 3, 0, PRICE_LOW, MODE_LOWER, 0) > OrderOpenPrice() && 
       iBands(Symbol(), 0, 22, 3, 0, PRICE_LOW, MODE_LOWER, 0) < Bid - MarketInfo(Symbol(), MODE_FREEZELEVEL)*Point)
      m = MathMax(m, iBands(Symbol(), 0, 22, 3, 0, PRICE_LOW, MODE_LOWER, 0));
   
   m = MathFloor(m / MathPow(10, -Digits)) * MathPow(10, -Digits);
   
   int err_code;
   for (int i=0; i<OrdersTotal() && OrderSelect(i, SELECT_BY_POS, MODE_TRADES); i++)
      if (OrderStopLoss() < m && m < Bid && Bid != m && m != OrderStopLoss())
         if(!OrderModify (OrderTicket(), OrderOpenPrice(), m, OrderTakeProfit(), OrderExpiration(), C'0x8f,0x7f,0x6f')) 
         {
            err_code = GetLastError();
            if (err_code == ERR_NO_ERROR || err_code == ERR_NO_RESULT)
               break;
            
            if (err_code == ERR_INVALID_STOPS)
            {
               Print("bid= ", Bid, " m=", m, " open=", OrderOpenPrice(), " sl=", OrderStopLoss());
               num_errors++;
            }
            
            Print("--------------------------------------------->", ErrorDescription(err_code));
         }

   /*if (i < OrdersTotal())
      num_errors++;*/
}

// calculate stop loss associated to lot size of next position.
double calc_sl()
{
   return (Ask * sl_prop);
}


/*
   Monitor of this EA.
*/
void monitor()
{
   if (num_errors > 0)
   {
      Comment("There ", num_errors, " errors occurred.");
      return;
   }

   // stopout level
   string stopout_l;
   if(AccountStopoutMode()==0)
      stopout_l = "%";
   else
      stopout_l = StringConcatenate(" ", AccountCurrency());
   
   // general account info
   Comment(
      StringConcatenate(AccountCompany(), "  server=", AccountServer(), "  usr=", AccountName(), "(num=", AccountCredit(), ")\n",
                        "leverage=", AccountLeverage(), " spread=", MarketInfo(Symbol(), MODE_SPREAD), "\n"),
      StringConcatenate("freeze-level= ", MarketInfo(Symbol(), MODE_FREEZELEVEL),
                        "  stop-level= ", MarketInfo(Symbol(), MODE_STOPLEVEL),
                        "  stopout=", AccountStopoutLevel(), stopout_l, "\n\n"),
                        
      StringConcatenate("initial: ", initial_deposit,
                        "   balance: ", AccountBalance(), " ", AccountCurrency(), 
                        "  equity: ", AccountEquity(), " ", AccountCurrency(),
                        "  equity/bal: ", AccountEquity()/AccountBalance(), "\n"),
      StringConcatenate("free-margin: ", AccountFreeMargin(), " ", AccountCurrency(), 
                        " (", 100 * AccountFreeMargin() / AccountEquity(),"% of equity)\n"),
      StringConcatenate("next lot size: ", lot_size(), " (", lot_prop(), "%) max-lote: ", lot_max(), "\n\n"),
      StringConcatenate("orders: ", OrdersTotal(), "\n\n")
   );
}

