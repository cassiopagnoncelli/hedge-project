//+------------------------------------------------------------------+
//| NEW YORK CLOSE
//|
//| Strategy developer:
//|    Gianni Gabriele 
//|    gigabrainy@libero.it
//| 
//| EA writer, and strategy modelling:
//|    Cássio Jandir Pagnoncelli 
//|    kimble9t@gmail.com
//|    www.inf.ufpr.br/cjp07
//|
//| -- version control --
//| last change: 09-november-2010.
//| current-version: 0.1-epsilon
//+------------------------------------------------------------------+
#property copyright "Gianni Gabriele; Cássio Pagnoncelli"
#property link      ""

#define current_version "0.1-epsilon"

/***
   DO NOT CHANGE THIS FILE.
***/

/*
   Automaton model for the strategy:
   ---------------------------------

                            on_time() == true AND
   check                    num_positions == 0 AND
   GBPUSD                     pendent_orders < 2
   ------->| start_state | ------------------------->| trading available state |<======) 0 or 1 out of 2 orders were put
                 /.\  |                                          |
                  |   |        num_positions > 0                 | 2 out of 2 orders were put
                  |   +--------------------------------------+   |
                  |             orders expired              \./ \./
                  +----------------------------------------| entries put |
                  |                                             |
                  |                                             | one pendent order turned into position
                  |                                             |
                  | the opened order were closed               \./
                  +-----------------------| cancel other pendent order and admin new position |

 | X |: state expressed as vertex of a graph
 ...->, <-..., /.\, \./: direction of the edge
 | X |<=====): loopback edge to the same X state
 +: edges merge resulting one single edge.
*/

#include <stderror.mqh>
#include <stdlib.mqh>

//---- input parameters
extern string    str0  = "# Only work if the pair is GBPUSD";
extern bool      pair_gbpusd = true;

extern string    str1   = "# Trade time";
extern int       hour = 10;
extern int       minute = 0;

extern string    str2   = "# CHANNEL is the HIGH/LOW...";
extern string    str2_0 = "TRUE: ...of the current 4-hour bar on chart";
extern string    str2_1 = "FALSE: ...prices in the last X minutes, where";
extern string    str2_2 = "X is the time considered to build the channel";
extern bool      channel_current_h4 = true;
extern int       channel_minutes_width = 240;
extern string    str2_3 = "Tolerance of entry\'s trigger (in pips)";
extern int       tolerance = 10;

extern string    str3   = "# Try to simulate OCO orders";
extern string    str3_0 = "(not working on this version, leave disabled)";
extern bool      simulate_oco = false;

extern string    str4   = "# T/P and S/L in pips (spreads are";
extern string    str4_0 = "automatically included)";
extern int       tp = 100;
extern int       sl = 25;

extern string    str5   = "# Slippage (maximum deviation in pips order";
extern string    str5_0 = "filled can differ from order put)";
extern int       slippage = 0;

extern string    str6   = "# Order expiration";
extern string    str6_0 = "Cancel entry orders whenever it is not filled";
extern string    str6_1 = "after \"expiration_in_hours\" hours";
extern int       expiration_in_hours = 9;

extern string    str7   = "# Break-even optimization";
extern string    str7_0 = "Move S/L to break-even when profit exceeds";
extern string    str7_1 = "\"breakeven_pips\" pips (set to 0 if you";
extern string    str7_2 = "want this optimization to be turned OFF)";
extern int       breakeven_pips = 50;

extern string    str8   = "# Pip value";
extern string    str8_0 = "(do not change it if you are uncertain)";
extern double    pip_value = 0.0001; // usually 0.0001

extern string    str9   = "# Show comments of screen";
extern bool      show_comments_on_screen = true;

extern string    stra   = "# Lot size calculation";
extern string    stra_0 = "Method [0=default_method;1=days_method]:";
extern string    stra_1 = "(\'day_of_increment\' and \'increment_at_each\'";
extern string    stra_2 = "is not considered on default and days method, ";
extern string    stra_3 = "respectively).";
extern int       method_lot_calc = 0;
extern string    stra_4 = "Initial size:";
extern double    initial_size = 1.0;
extern string    stra_5 = "increments by:";
extern double    increment = 0.1; 
extern string    stra_6 = "at each \"increment_at_each\" filled orders";
extern string    stra_7 = "(set this to 0 NOT to consider increments):";
extern int       increment_at_each = 15;
extern string    stra_8 = "day of increment [1-31]:";
extern int       day_of_increment = 10;

extern string    strb   = "# Advice me by email";
extern bool      advice_mail = true;

extern string    strc   = "# Actions on very fast market movement.";
extern string    strc_0 = "Advancing on buy/sell at market price";
extern bool      advance_fast_market = true;
extern string    strc_1 = "Buy/Sell only if market price is ";
extern string    strc_2 = "\"advance_pips\" pips closer of the Breakout ";
extern string    strc_3 = "Entry price (set 0 to advance disconsidering";
extern string    strc_4 = "this price difference)";
extern int       advance_pips = 15;

//---- control of the robot
/* New York Close's magic number */
#define NYCLOSE_MAGIC 101024
/*-- states --
  0: start state
  1: trading available AND if not in optimization wait for 5 secs.
  2: entries were put sucessfully
  3: cancels other pendent orders opened and admin the new position
*/
int machine_state;

// initialization
int init() {
   // set initial state-machine to 0
   machine_state = 0;
   
   // check if the pair is GBPUSD
   if (!check_gbpusd())
      Comment(StringConcatenate("New York Close EA is not running over GBPUSD pair. \n",
         "To unlock running this EA over other pairs, set `pair_gbpusd\' to FALSE on parameters of EA."));
   
   return(0);
}

// deinitialization
int deinit() {
   return(0);
}

// tick-by-tick
int start() {
   // check if the pair is GBPUSD
   if (!check_gbpusd())
      return (0);

   // show comments of what is happening currently   
   if (show_comments_on_screen && !IsOptimization())
      show_comments();

   /*  -- states --
      0: start state
      1: trading available AND if not in optimization wait for 5 secs.
      2: entries were put sucessfully
      3: cancels other pendent orders opened and admin the new position
   */
   int i;
   switch (machine_state) {
   case 0: // start state
      // run EA only when it is in the right time (10.00 AM), no opened position and less than two pendent orders
      if (on_time() && num_opened_positions() == 0 && num_pendent_orders() < 2) {
         machine_state = 1;
      } else 
      // if EA was closed or restarted after placed Entry Order
      // we must restore the right machine state value!
      if (num_opened_positions()>0) 
         machine_state=2;
   break;
   case 1: // trading available
      if (!IsOptimization()) Sleep(3);
      
      // cancel pendent positions
      bool deletation = false;
      for (i=0; i<OrdersTotal() && OrderSelect(i, SELECT_BY_POS, MODE_TRADES); i++)
         if (OrderMagicNumber() == NYCLOSE_MAGIC && (OrderType() == OP_BUYSTOP || OrderType() == OP_SELLSTOP)) {
            OrderDelete(OrderTicket());
            deletation = true;
         }
      
      // buy/sell if it is the proper time and situation
      if (num_opened_positions() == 0 && num_pendent_orders() == 0) {
         bool 
            advance_buy  = MathAbs(Ask - price(channel_high(), tp)) < MathAbs(Bid - price(channel_low(), -tp))
                        && MathAbs(Ask - price(channel_high(), 0)) <= price(0, advance_pips),
            advance_sell = MathAbs(Bid - price(channel_low(), -tp)) < MathAbs(Ask - price(channel_high(), tp))
                        && MathAbs(Bid - price(channel_low(), 0)) <= price(0, advance_pips);
         bool advance = advance_fast_market && (advance_pips == 0 || (advance_buy || advance_sell));
      
         // put breakout entries if movements of price is normal
         if (GetLastError() != ERR_OFF_QUOTES) {
            RefreshRates(); // get new quotes
         
            // entry buy 
            bool buy = true;

            double p = channel_high();
            if (Ask < price(p, tolerance - MarketInfo(Symbol(), MODE_FREEZELEVEL)))
               buy  = put_breakout_entry(OP_BUYSTOP,  p, price(p, tp), price(p, -sl));
         
            // entry sell
            bool sell = true;
            p = channel_low();
            if (Bid > price(p, -tolerance + MarketInfo(Symbol(), MODE_FREEZELEVEL)))
               sell = put_breakout_entry(OP_SELLSTOP, p, price(p, -tp), price(p, sl));
      
            if (buy && sell) {
               machine_state = 2;
               sendmail_and_print("Daily Entry Order successfully created (Buy & Sell)",
                  StringConcatenate("DUE Ordini del Giorno Creati correttamente. ",Day()," ",Hour(), ":",Minute()),
                  "Daily Entry Order successfully created (Buy & Sell)");
            }
         } else 
         // market movements are very very fast, so we are going to advance buying (or selling, if it is the occasion)
         if (advance)
         {
            Alert("Fast market movements, looking for advancing a buy/sell.");
            
            // price is closer to entry buy or closer to entry sell? 
            // if it is to entry buy, we are going to buy
            if (MathAbs(Ask - price(channel_high(), tp)) < MathAbs(Bid - price(channel_low(), -tp))) {
               int buy_ticket = OrderSend(Symbol(), OP_BUY, lot_size(), Ask, slippage, price(Ask, -sl), price(Ask, tp), 
                             "Bought at market price", NYCLOSE_MAGIC, 0, DeepSkyBlue);
               if (buy_ticket < 0)
                  sendmail_and_print("Very fast market movement: advance in buying failed",
                     ErrorDescription(GetLastError()),
                     "Advance in buying failed on very fast market movement.");
               else {
                  sendmail_and_print("Advance in buying at market price successful.",
                     StringConcatenate("New position opened on advancing buy at market price.",
                        "\nopen: ", Ask,
                        "\nslippage: ", slippage,
                        "\nsl: ", price(Ask, -sl),
                        "\ntp: ", price(Ask, tp)),
                     "Advance in buying successful, description was sent to email.");
                  
                  // once position is opened, move to state 3, that controls this new opened order stop loss.
                  machine_state = 3;
               }
            } else // if we are closer to sell, we are going to sell
            if (MathAbs(Bid - price(channel_low(), -tp)) < MathAbs(Ask - price(channel_high(), tp))) {
               int sell_ticket = OrderSend(Symbol(), OP_SELL, lot_size(), Bid, slippage, price(Bid, sl), price(Bid, -tp), 
                             "Sold at market price", NYCLOSE_MAGIC, 0, DeepSkyBlue);
               if (sell_ticket < 0)
                  sendmail_and_print("Very fast market movement: advance in selling failed",
                     ErrorDescription(GetLastError()),
                     "Advance in selling failed on very fast market movement, description was sent to email.");
               else {
                  sendmail_and_print("Advance in selling at market price successful.",
                     StringConcatenate("New position opened on advancing sell at market price.",
                        "\nopen: ", Bid,
                        "\nslippage: ", slippage,
                        "\nsl: ", price(Bid, sl),
                        "\ntp: ", price(Bid, -tp)),
                     "Advance in selling successful.");
                  
                  // once position is opened, move to state 3, that controls this new opened order stop loss.
                  machine_state = 3;
               }
            } else { // if price is on the middle of them, try again
            }
         } else 
         // there are placed orders, or NO advace was taken
         {
            if (!deletation) // try again cancelling pendent orders. If cancelling is not sufficient, we go to start state
               machine_state = 0;
         }
      }
   break;
   case 2: // entries put
      int opened = num_opened_positions(), pendents = num_pendent_orders();
      if (opened == 0 && pendents == 0)
         machine_state = 0;
      else 
      if (opened == 1 && pendents == 0) {
         machine_state = 3;
         sendmail_and_print("Actually One Position and Zero pendent Orders",
            StringConcatenate(Day(),"/",Month()," ",Hour(), ":",Minute()),
            "Actually: One Position and Zero pendent Orders");
      } else
      if (opened == 2 && pendents == 0) { // it seems this situation will never happen
         machine_state = 3;
         sendmail_and_print("WARNING!!! TWO OPEN POSITIONS",
            StringConcatenate("2 OPEN Positions",Day()," ",Hour(), ":",Minute()),
            "WARNING: There are TWO OPEN POSITIONS");
      } else
      if (opened == 1 && pendents == 1) {
         machine_state = 3;
         sendmail_and_print("Open Position and Pendent Order",
            StringConcatenate("1 OPEN Position + 1 Pendent Order ",Day()," ",Hour(), ":",Minute()),
            "Open Positions:1 , Pendent Orders:1");
      } /*else
      if (opened == 0 && pendents == 1); // soon the other pendent position will be cancelled
      else
      if (opened == 0 && pendents == 2); // nothing to do, keep on this state
      */
   break;
   case 3:
      // cancel the remaining pendent position
      int pos = -1;
      bool delete_successful = true, deletation_state3 = false;
      for (i=0; i<OrdersTotal() && OrderSelect(i, SELECT_BY_POS, MODE_TRADES); i++)
         if (OrderMagicNumber() == NYCLOSE_MAGIC) {
            if (OrderType() == OP_BUYSTOP || OrderType() == OP_SELLSTOP) {
               if (!OrderDelete(OrderTicket())) {
                  delete_successful = false;
                  deletation_state3 = true;
               }
            } else
            if (OrderType() == OP_BUY || OrderType() == OP_SELL)
               pos = i;
         }
      
      // advice by mail whether or not pendent orders were successful canceled.
      if (deletation_state3) {
         if (delete_successful)
            sendmail_and_print("Pendent Order cancelled",
               StringConcatenate("All the ", i, " pendent orders were cancelled at ", Day(), " ", Hour(), ":",Minute()),
               "Pendent Orders cancelled");
         else
            sendmail_and_print("One or more pendent orders were NOT cancelled",
               "Seconds ago EA tried to cancel remaining pendent orders and was not sucessful.",
               ErrorDescription(GetLastError()));
      }
      
      // position has been closed
      if (pos == -1) {
         machine_state = 0;
         sendmail_and_print("Opened order(s) were closed", "", "Opened orders were closed, see last lines.");
      } else // position is opened and must have its stop loss managed
         set_sl_to_breakeven(pos);
   break;
   default:
      // invalid state.
   break;
   }
   
   return(0);
}

//--- EA functions ---
// on time
bool on_time() {
   return (Hour() == hour && Minute() == minute);
}

// check if is GBPUSD
bool check_gbpusd() {
   if (StringFind(Symbol(), "GBPUSD", 0) != -1)
      return (true);
   if (StringFind(Symbol(), "gbpusd", 0) != -1)
      return (true);
   return (false);
}

// price deviation in pips
double price(double p, int pips) {
   return (p + pips * pip_value); 
}

// CHANNEL's high
double channel_high() {
   if (channel_current_h4)
      return (price(iHigh(Symbol(), PERIOD_H4, 0), tolerance));
   else {
      //if (iHighest(Symbol(), 0, MODE_HIGH, channel_minutes_width/Period(), 1) == -1) Alert("ihighest=-1"); // for debug
      return (price(iHigh(Symbol(), PERIOD_H4, iHighest(Symbol(), 0, MODE_HIGH, channel_minutes_width/Period(), 1)), 
              tolerance));
   }
}

// CHANNEL's low
double channel_low() {
   if (channel_current_h4)
      return (price(iLow(Symbol(), PERIOD_H4, 0), -tolerance));
   else
      return (price(iLow(Symbol(), PERIOD_H4, iLowest(Symbol(), 0, MODE_LOW, channel_minutes_width/Period(), 1)), 
                    -tolerance));
}

// put the entry order
bool put_breakout_entry(int entry_order_type, double p, double take_profit, double stop_loss) {
   return (OrderSend(Symbol(), entry_order_type, lot_size(), p, slippage, stop_loss, take_profit, 
                     NULL, NYCLOSE_MAGIC, TimeCurrent() + expiration_in_hours * 3600) != -1); 
   /*if (OrderSend(Symbol(), entry_order_type, lot_size(), p, slippage, stop_loss, take_profit, // debug purpose
         NULL, NYCLOSE_MAGIC, TimeCurrent() + expiration_in_hours * 3600) == -1)
      Alert("trying to ordersend. p=", p, ",lot=", lot_size(), ",sl=", stop_loss, ",tp=", 
            take_profit, ",buy=", entry_order_type==OP_BUYSTOP, ",bid=", Bid);*/
}

// show comments of screen about what is happening
void show_comments() {
   switch (machine_state) {
   case 0: 
      Comment("Nothing being done.");
   break;
   case 1:
      Comment("Trading time, trying to put correctly put the 2 orders, this may not long too much...");
   break;
   case 2:
      Comment("Two breakout entry orders were put: one for buy, and one for sell.");
   break;
   case 3:
      Comment(StringConcatenate("One breakout entry order turned into a active position, ",
         "now the remaining pendent order must be cancelled and the new position must be managed.\n",
         "No other positions nor new breakout entries will be put until the current position be closed."));
   break;
   default: 
      Comment("ERROR: You should NEVER see this warning. It is recomended you to turn OFF the EA.");
   break;
   }
   
   int last_error = GetLastError();
   if (GetLastError() != 0)
      Comment("error #", last_error, ": ", ErrorDescription(last_error));
}

// lote size calculation
double lot_size() {
   int i;
   switch (method_lot_calc) {
   case 0: { //default method
      if (increment_at_each <= 0)
         return (initial_size);

      int fifteen_filled_orders = 0;
      for (i=0; i<OrdersHistoryTotal() && OrderSelect(i, SELECT_BY_POS, MODE_HISTORY); i++)
         if (OrderMagicNumber() == NYCLOSE_MAGIC)
            fifteen_filled_orders++;
   
      fifteen_filled_orders /= increment_at_each;
      return (initial_size + increment * fifteen_filled_orders);
   } break;
   case 1: { // days method (on testing)
      double basis_lot = initial_size;
      
      // get number of months EA is active till now
      int months_dev = 0;
      /*for(i=OrdersHistoryTotal()-1; i>=0 && OrderSelect(i, SELECT_BY_POS, MODE_HISTORY); i--)
         if (OrderMagicNumber() == NYCLOSE_MAGIC) {
            months_dev = 12 * (Year() - TimeYear(OrderOpenTime())) + (Month() - TimeMonth(OrderOpenTime()));
            //basis_lot = OrderLots();
            i = -1;
         }*/
      for(i=0; i<OrdersHistoryTotal() && OrderSelect(i, SELECT_BY_POS, MODE_HISTORY); i++)
         if (OrderMagicNumber() == NYCLOSE_MAGIC) {
            months_dev = 12 * (Year() - TimeYear(OrderOpenTime())) + (Month() - TimeMonth(OrderOpenTime()));
            //basis_lot = OrderLots();
            i = OrdersHistoryTotal();
         }
      
      if (Day() >= day_of_increment)
         months_dev++;
      
      Alert("basis=", basis_lot, ",months_dev=", months_dev, ",increment=", increment, ",size=",
         basis_lot + months_dev * increment);
      
      return (basis_lot + months_dev * increment);
   } break;
   default: {
      sendmail_and_print("No method for lot calculation chosen...",
         "...choose one of the parameters list in order to enable EA.",
         "No lot size calculation method chosen.");
      return (0);
   } break;
   }   
}

// active pendent orders number
int num_pendent_orders() {
   int pendent_orders = 0;
   for (int i=0; i<OrdersTotal() && OrderSelect(i, SELECT_BY_POS, MODE_TRADES); i++)
      if (OrderMagicNumber() == NYCLOSE_MAGIC && (OrderType() == OP_BUYSTOP || OrderType() == OP_SELLSTOP))
         pendent_orders++;

   return (pendent_orders);
}

// active opened positions number
int num_opened_positions() {
   int opened_positions = 0;
   for (int i=0; i<OrdersTotal() && OrderSelect(i, SELECT_BY_POS, MODE_TRADES); i++)
      if (OrderMagicNumber() == NYCLOSE_MAGIC && (OrderType() == OP_BUY || OrderType() == OP_SELL))
         opened_positions++;

   return (opened_positions);
}

// set sl of the position to breakeven whenever it exceed `breakeven_pips' pips in profit
void set_sl_to_breakeven(int pos) {
   if (!OrderSelect(pos, SELECT_BY_POS, MODE_TRADES))
      return;
   
   // verify for not break-even situation
   if (OrderType() == OP_BUY  && Bid < price(OrderOpenPrice(),  breakeven_pips))
      return;
   else
   if (OrderType() == OP_SELL && Ask > price(OrderOpenPrice(), -breakeven_pips))
      return;
   
   // possible errors are sl and open price be very near, and sl is in tp domain, and sl = open price
   if (MathAbs(OrderOpenPrice() - OrderStopLoss()) <= MarketInfo(Symbol(), MODE_SPREAD) * pip_value)
      return;
   
   // set sl to break-even
   if (!OrderModify(OrderTicket(), OrderOpenPrice(), OrderOpenPrice(), OrderTakeProfit(), 0))
      Alert(StringConcatenate("Could not set set position\'s stop loss to break-even. ",
                              "If this error perdure, contact the EA writer. ",
         "debug:open=", OrderOpenPrice(), ",sl=", OrderStopLoss(), 
         ",buy?=", OrderType()==OP_BUY, ",bid=", Bid));
}

//
void sendmail_and_print(string email_subject, string email_msg, string print_str) {
   if (advice_mail)
      SendMail(
         StringConcatenate("[NewYorkClose] ", email_subject), 
         StringConcatenate("NewYorkClose\n------------\n\n", 
            email_msg, 
            "\n\n----\ncurrent version: ", current_version, 
            "\nlast known server time by the moment: ", Hour(), ":", Minute()));
   
   if (!IsOptimization())
      Print(print_str);
}