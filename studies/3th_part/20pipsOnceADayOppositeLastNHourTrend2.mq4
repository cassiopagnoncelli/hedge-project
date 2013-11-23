#property copyright "slacktrader"
#property link      ""

#define  MAGICMA           0

string   SYMBOL;
int      TIMEFRAME         = 0;
int      MAXORDERS         = 1;

int      TRADINGDAYHOURS[] = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23};

//Expert Settings
double   FIXLOT            = 0;      //if 0, uses maximumrisk, else uses only this while trading
double   MINLOTS           = 0.1;      //minimum lot
double   MAXLOTS           = 5;        //maximum lot
double   MAXIMUMRISK       = 0.01;     //maximum risk, if FIXLOT = 0
int      SLIPPAGE          = 3;        //max slippage alowed

int      TRADINGHOUR       = 7;        //time when position should be oppened
int      HOURSTOCHECKTREND  = 30;      //amount of hours to check price difference to see a "trend"
int      ORDERMAXAGE       = 75600;    //max age of position - closes older positions

extern int      FIRSTMULTIPLICATOR   = 3;     //multiply lots when position -1 was loss
extern int      SECONDMULTIPLICATOR  = 0;     //multiply lots when position -2 was loss
extern int      THIRDMULTIPLICATOR   = 1;     //multiply lots when position -3 was loss
extern int      FOURTHMULTIPLICATOR  = 5;     //multiply lots when position -4 was loss
extern int      FIFTHMULTIPLICATOR   = 1;     //multiply lots when position -5 was loss

extern int      WINMULTIPLICATOR     = 2;     //multiply lots when position -1 was win

extern double   STOPLOSS          = 80;       //SL
extern double   TRAILINGSTOP      = 0;        //
extern double   TAKEPROFIT        = 20;       //TP

//Globals
datetime LastBarTraded     = 0;
//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
int init()
{
//---- 
   SYMBOL = Symbol();
//----
   return(0);
}
//+------------------------------------------------------------------+
//| expert deinitialization function                                 |
//+------------------------------------------------------------------+
int deinit()
{
//---- 
   
//----
   return(0);
}
//+------------------------------------------------------------------+
//| expert start function                                            |
//+------------------------------------------------------------------+
void start()
{
   CheckForClosePositions();   
   CheckForModifyPositions();
   if(TradeAllowed())
      OpenPosition(CheckForOpenPosition(), GetLots());     
}
//+------------------------------------------------------------------+
//| TradeAllowed function return true if trading is possible         |
//+------------------------------------------------------------------+
bool TradeAllowed()
{
//Trade only once on each bar
   if(LastBarTraded == Time[0])
      return(false);
//Trade only open price of current hour
   if(iVolume(SYMBOL, PERIOD_H1, 0) > 1)
      return(false);
   if(!IsTradeAllowed()) 
      return(false);
   if(OrdersTotal() >= MAXORDERS)
      return(false);
   if(!IsTradingHour())
   {
      CloseAllPositions();
      return(false);
   }
   return(true);
}

bool IsTradingHour()
{
   int i;
   bool istradinghour = false;

   for(i = 0; i < ArraySize(TRADINGDAYHOURS); i++)
   {
      if(TRADINGDAYHOURS[i] == Hour())
      {
         istradinghour = true;
         break;
      }      
   }
   return(istradinghour);
}
//+------------------------------------------------------------------+
//| Get amount of lots to trade                                      |
//+------------------------------------------------------------------+

// this function describes how to find a best LOT size and check its correctness
// http://book.mql4.com/build/lots

double GetLots()
{
   double lot, result;
   
   if(FIXLOT == 0)
   {
//      lot = NormalizeDouble(AccountFreeMargin() * MAXIMUMRISK * / STOPLOSS * , 1);

//      double riskAmount = AccountBalance() * MAXIMUMRISK;
        double riskAmount = AccountFreeMargin() * MAXIMUMRISK;

      
      lot = NormalizeDouble(riskAmount / (STOPLOSS * MarketInfo(Symbol(), MODE_TICKVALUE)), 1);  
   }
   else
      lot = NormalizeDouble(FIXLOT, 1);

//   Print(AccountFreeMargin());
//   Print(ticks, " ", riskAmount, " ", lot);
   
/* Original version

   OrderSelect(OrdersHistoryTotal() - 1, SELECT_BY_POS, MODE_HISTORY);
   if(OrderProfit() < 0)
      lot = lot * FIRSTMULTIPLICATOR;
   else
   {
      OrderSelect(OrdersHistoryTotal() - 2, SELECT_BY_POS, MODE_HISTORY);
      if(OrderProfit() < 0)
         lot = lot * SECONDMULTIPLICATOR;
      else
      {
         OrderSelect(OrdersHistoryTotal() - 3, SELECT_BY_POS, MODE_HISTORY);
         if(OrderProfit() < 0)
            lot = lot * THIRDMULTIPLICATOR;
         else
         {
            OrderSelect(OrdersHistoryTotal() - 4, SELECT_BY_POS, MODE_HISTORY);
            if(OrderProfit() < 0)
               lot = lot * FOURTHMULTIPLICATOR;
            else
            {
               OrderSelect(OrdersHistoryTotal() - 5, SELECT_BY_POS, MODE_HISTORY);
               if(OrderProfit() < 0)
                  lot = lot * FIFTHMULTIPLICATOR;
            }
         }
      }
   }
*/

/* Multiply LOTS also if Win
*/

   OrderSelect(OrdersHistoryTotal() - 4, SELECT_BY_POS, MODE_HISTORY);
   if(OrderProfit() <= 0)
   {
      OrderSelect(OrdersHistoryTotal() - 3, SELECT_BY_POS, MODE_HISTORY);
      if(OrderProfit() > 0)
      {
         OrderSelect(OrdersHistoryTotal() - 2, SELECT_BY_POS, MODE_HISTORY);
         if(OrderProfit() > 0)
         {
            OrderSelect(OrdersHistoryTotal() - 1, SELECT_BY_POS, MODE_HISTORY);
            if(OrderProfit() > 0)
               lot = MAXLOTS; // este by som zmenil TP na trailing a zuzil by som SL
   //         lot = NormalizeDouble(OrderLots() * WINMULTIPLICATOR, 1);
   //      lot = NormalizeDouble(lot * WINMULTIPLICATOR, 1);
   //      lot = NormalizeDouble(lot * WINMULTIPLICATOR, 1);
   //      lot = NormalizeDouble(OrderLots() + MarketInfo(Symbol(), MODE_LOTSTEP)*WINMULTIPLICATOR, 1);
   //      lot = NormalizeDouble(OrderLots() + MarketInfo(Symbol(), MODE_LOTSTEP)*WINMULTIPLICATOR, 1);
         }
      }
   }

/*
   OrderSelect(OrdersHistoryTotal() - 1, SELECT_BY_POS, MODE_HISTORY);
   if(OrderProfit() < 0)
   {
      lot = OrderLots()*2;
      OrderSelect(OrdersHistoryTotal() - 2, SELECT_BY_POS, MODE_HISTORY);
      if(OrderProfit() < 0)
      {
         lot = OrderLots()*4;
         OrderSelect(OrdersHistoryTotal() - 3, SELECT_BY_POS, MODE_HISTORY);
         if(OrderProfit() < 0)
         {
            lot = OrderLots()*8;
            OrderSelect(OrdersHistoryTotal() - 4, SELECT_BY_POS, MODE_HISTORY);
            if(OrderProfit() < 0)
            {
               lot = OrderLots()*16;
               OrderSelect(OrdersHistoryTotal() - 5, SELECT_BY_POS, MODE_HISTORY);
               if(OrderProfit() < 0)
                  lot = OrderLots()*32;
            }
         }
      }
   }
*/
       
//   Print(lot, " ", AccountFreeMargin(), " ", MarketInfo(Symbol(), MODE_TICKVALUE));   
   if(lot < MINLOTS)
      lot = MINLOTS;

// While lot size takes more than available margin, lower lot size
//   while(AccountFreeMarginCheck(SYMBOL, OP_SELL, lot) < 0)

// While lot size takes more than half of margin, lower lot size
   while(AccountFreeMarginCheck(SYMBOL, OP_SELL, lot) < AccountFreeMargin()/2)
   {
      lot = NormalizeDouble(lot - MarketInfo(SYMBOL, MODE_LOTSTEP), 1);
//      Print(lot, " ", AccountFreeMargin(), " ", MarketInfo(Symbol(), MODE_TICKVALUE));   
      if(lot < MINLOTS)
         return;
   }   

//   Print(lot, " ", AccountFreeMargin(), " ", MarketInfo(Symbol(), MODE_TICKVALUE));

   if(lot < MINLOTS)
      lot = MINLOTS;
   else if(lot > MAXLOTS)
      lot = MAXLOTS;
      
   return(lot);
   
   
}
//+------------------------------------------------------------------+
//| Checks of open short, long or nothing (-1, 1, 0)                 |
//+------------------------------------------------------------------+
int CheckForOpenPosition()
{
   int result = 0;

//Trade only this hour in a day - once a day at this time
   if(Hour() != TRADINGHOUR)
      return(result);
      
//Long if last N hour was bearish - short when last N hour was bullish
   if(iClose(SYMBOL, PERIOD_H1, HOURSTOCHECKTREND) > iClose(SYMBOL, PERIOD_H1, 1))
      result = 1;
   else
      result = -1;

//----
   return(result);
}
//+------------------------------------------------------------------------------------+
//| Opens position according to arguments (-1 short || 1 long, amount of Lots to trade |
//+------------------------------------------------------------------------------------+
void OpenPosition(int ShortLong, double Lots)
{
   double SL, TP;
   if(ShortLong == -1)
   {
      if(STOPLOSS != 0)
         SL = Bid + STOPLOSS * Point;
      else
         SL = 0;
      if(TAKEPROFIT != 0)
         TP = Bid - TAKEPROFIT * Point;
      else
         TP = 0;
      OrderSend(SYMBOL, OP_SELL, Lots, Bid, SLIPPAGE, SL, TP, TimeToStr(Time[0]), MAGICMA, 0, Red);
   }
   else if(ShortLong == 1)
   {
      if(STOPLOSS != 0)
         SL = Ask - STOPLOSS * Point;
      else
         SL = 0;
      if(TAKEPROFIT != 0)
         TP = Ask + TAKEPROFIT * Point;
      else
         TP = 0;
      OrderSend(SYMBOL, OP_BUY, Lots, Ask, SLIPPAGE, SL, TP, TimeToStr(Time[0]), MAGICMA, 0, Blue);
   }
   if(ShortLong != 0)
      LastBarTraded = Time[0];
}
//
void ClosePositions(int OrderTickets2Close[])
{
   int i;
   
   for(i = 0; i < ArraySize(OrderTickets2Close); i++)
   {
      OrderSelect(OrderTickets2Close[i], SELECT_BY_TICKET);
      if(OrderType() == OP_SELL)
         OrderClose(OrderTicket(), OrderLots(), Ask, 3, Orange);
      else if(OrderType() == OP_BUY)
         OrderClose(OrderTicket(), OrderLots(), Bid, 3, Orange);
   }
}
//
void CloseAllPositions()
{
   int i;
   int OrderTickets2Close[];
   ArrayResize(OrderTickets2Close, 0);
   
   for(i = 0; i < OrdersTotal(); i++)
   {
      OrderSelect(i, SELECT_BY_POS);
      ArrayResize(OrderTickets2Close, i + 1);
      OrderTickets2Close[i] = OrderTicket();
   }

   ClosePositions(OrderTickets2Close);
}
//+------------------------------------------------------------------------------------+
//| Closes position based on indicator state                                           |
//+------------------------------------------------------------------------------------+
void CheckForClosePositions()
{
   int i, j;   
   int OrderTickets2Close[];
   ArrayResize(OrderTickets2Close, 0);

   for(i = 0; i < OrdersTotal(); i++)
   {
      OrderSelect(i, SELECT_BY_POS);
      if(OrderType() == OP_BUY && OrderOpenTime() + ORDERMAXAGE < TimeCurrent())
      {
         ArrayResize(OrderTickets2Close, j + 1);
         OrderTickets2Close[i] = OrderTicket();
         j++;
      }
   }
   for(i = 0; i < OrdersTotal(); i++)
   {
      OrderSelect(i, SELECT_BY_POS);
      if(OrderType() == OP_SELL && OrderOpenTime() + ORDERMAXAGE < TimeCurrent())
      {
         ArrayResize(OrderTickets2Close, j + 1);
         OrderTickets2Close[i] = OrderTicket();
         j++;
      }
   }
   
   ClosePositions(OrderTickets2Close);
   
//----
   return;
}
//+------------------------------------------------------------------------------------+
//| Modify positions - Stoploss based on Trailing stop                                            |
//+------------------------------------------------------------------------------------+
void CheckForModifyPositions()
{
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES) == false)
         break;
      if(OrderMagicNumber() != MAGICMA || OrderSymbol() != SYMBOL)
         continue;

      if(OrderType() == OP_BUY)
      {
         if(TRAILINGSTOP > 0)
            if(Bid - OrderOpenPrice() > Point * TRAILINGSTOP)
              if(OrderStopLoss() < Bid-Point * TRAILINGSTOP)
                 OrderModify(OrderTicket(), OrderOpenPrice(), Bid - Point*TRAILINGSTOP, OrderTakeProfit(), 0, Blue);
      }
      else if(OrderType() == OP_SELL)
      {
         if(TRAILINGSTOP > 0)
            if(Ask + OrderOpenPrice() < Point * TRAILINGSTOP)
              if(OrderStopLoss()>Ask + Point * TRAILINGSTOP)
                 OrderModify(OrderTicket(), OrderOpenPrice(), Ask + Point * TRAILINGSTOP, OrderTakeProfit(), 0, Red);
      }
   }
}