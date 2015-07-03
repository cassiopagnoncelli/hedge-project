//+------------------------------------------------------------------+
//|                                               AccountMonitor.mq4 |
//|                                        Cássio Jandir Pagnoncelli |
//|                                     http://www.inf.ufpr.br/cjp07 |
//+------------------------------------------------------------------+
#property copyright "Cássio Jandir Pagnoncelli"
#property link      "http://www.inf.ufpr.br/cjp07"
#property indicator_chart_window
#define versao "0.1"

/* input parameters. */
extern double deposit = 319;

/* global vars. */
double min_margin_level = 99999999;
double max_margin_level = 0;

/* init, deinit, start. */
int init()
{
  /*ObjectCreate("AccountMonitor", OBJ_LABEL, WindowFind("AccountMonitor"), TimeCurrent(), Bid);*/
  Comment(Monitor());
  return(0);
}

int deinit()
{
  /*ObjectDelete("AccountMonitor");*/
  return(0);
}

int start()
{
  /*ObjectSetText("AccountMonitor", Monitor(), 7, "Tahoma", Black);
  ObjectSet("AccountMonitor", OBJPROP_XDISTANCE, 5);
  ObjectSet("AccountMonitor", OBJPROP_YDISTANCE, 15);*/
  return(0);
}

/* monitoring. */
string Monitor()
{
  string str = "ACCOUNT INFORMATION\n" + account_information() + "\n\n";

  if (OrdersTotal() > 0) {
    if (AccountMargin() > 0)
      str = str + "FLOATING\n" + floating() + "\n\n";
    
    str = str + positions();
  }
  
  return (str);
}

string is_live()
{
  if (IsDemo())
    return ("demo");
  return ("live");
}

string floating()
{
  calculations();
  
  string
    str = "Equity: " + DoubleToStr(AccountEquity(), 2) + " (= " 
        + DoubleToStr(AccountEquity() * MarketInfo("GLDUSD", MODE_BID), 2) + " USD), "
        + "margin: " + DoubleToStr(AccountMargin(), 2) 
        + " (= " + DoubleToStr(AccountMargin() * MarketInfo("GLDUSD", MODE_BID), 2) + "USD)\n"
        + "Floating ROI currently at " + DoubleToStr(AccountEquity() / deposit, 4) + " and "
        + "this account will be stopped out at " + DoubleToStr(stopout(), 4) + " floating ROI level\n"
        + "Margin level at " + DoubleToStr(AccountEquity()/AccountMargin() * 100, 2) 
        + "% (min=" + DoubleToStr(min_margin_level, 4) + " and max=" + DoubleToStr(max_margin_level, 4) + ")\n"
        + "Available margin and margin ratio is " + DoubleToStr(AccountFreeMargin() / AccountMargin(), 2) 
        + " and free margin represents "
        + DoubleToStr(AccountFreeMargin() / AccountEquity() * 100, 2) + "% of your equity\n"
        + "Profit: " + DoubleToStr(AccountProfit(), 2) + " " + AccountCurrency() + " (= " 
        + DoubleToStr(AccountProfit() * MarketInfo("GLDUSD", MODE_BID), 2) + " USD)";

  return (str);
}

double stopout()
{
  if (AccountStopoutMode() == 0)
    return (AccountStopoutLevel() * AccountMargin() / AccountEquity() / 100);
  return (AccountStopoutLevel() / AccountEquity());
}

string time_difference(int seconds)
{
  int sec = seconds % 60;
  int min = ((seconds - sec) % 3600) / 60;
  int hours = ((seconds - 60*min - sec) % 86400) / 3600;
  
  if (hours == 0) {
    if (min == 0) {
      return (sec + "s");
    } else
      return (min + "min" + sec + "s");
  } else
    return (hours + "h" + min + "min" + sec + "s");
}

string day_week(int unix_time)
{
  datetime t = unix_time;
  switch (TimeDayOfWeek(t)) {
  case 0: return ("Sun"); break;
  case 1: return ("Mon"); break;
  case 2: return ("Tue"); break;
  case 3: return ("Wed"); break;
  case 4: return ("Thu"); break;
  case 5: return ("Fri"); break;
  case 6: return ("Sat"); break;
  }
}

string account_information()
{
  return ("Connected to " + AccountServer() + " in " + AccountCompany() + " server\n"
        + "Last known server time, " + day_week(TimeCurrent()) + " " 
        +  TimeToStr(TimeCurrent(), TIME_MINUTES | TIME_SECONDS) + ", differs "
        + time_difference(MathAbs(TimeCurrent() - TimeLocal())) + " from local time " + day_week(TimeLocal()) 
        + " " + TimeToStr(TimeLocal(), TIME_MINUTES | TIME_SECONDS) + "\n"
        + "This " + is_live() + " account is held by " + AccountName() + " with ID " + AccountNumber() + "\n"
        + "Base currency is " + AccountCurrency() + " and leverage set to 1:" + AccountLeverage() + "\n"
        + "Balance at " + DoubleToStr(AccountBalance(), 2) + " " + AccountCurrency() + " (= "
        + DoubleToStr(AccountBalance() * MarketInfo("GLDUSD", MODE_BID), 2) + " USD) from initially "
        + DoubleToStr(deposit, 2) + " " + AccountCurrency()
        + " yielding ROI " + DoubleToStr(AccountEquity()/deposit, 4));
}

string positions()
{
  string str;
  if (OrdersTotal() > 0)
    str = "POSITIONS\n";
  
  for (int i=0; i<OrdersTotal() && OrderSelect(i, SELECT_BY_POS); i++)
    switch (OrderType()) {
    case OP_BUY:
      str  = str + "+" + DoubleToStr(OrderLots(), 2) + " of " + OrderSymbol()
           + " at " + DoubleToStr(OrderOpenPrice(), MarketInfo(OrderSymbol(), MODE_DIGITS))
           + " floating " + DoubleToStr(OrderProfit(), 2) + " " + AccountCurrency()
           + "\n";
    break;
    case OP_SELL:
      str  = str + "-" + DoubleToStr(OrderLots(), 2) + " of " + OrderSymbol()
           + " at " + DoubleToStr(OrderOpenPrice(), MarketInfo(OrderSymbol(), MODE_DIGITS))
           + " floating " + DoubleToStr(OrderProfit(), 2) + " " + AccountCurrency()
           + "\n";
    break;
    }

  return (str);
}

void calculations()
{
  min_margin_level = MathMin(min_margin_level, AccountEquity()/AccountMargin());
  max_margin_level = MathMax(max_margin_level, AccountEquity()/AccountMargin());
}
