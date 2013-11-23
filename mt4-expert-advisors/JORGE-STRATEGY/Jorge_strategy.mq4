//+------------------------------------------------------------------+
//|                                               Jorge_strategy.mq4 |
//|                            AMARAL, Jorge; PAGNONCELLI, Cássio J. |
//|                                               kimble9t@gmail.com |
//+------------------------------------------------------------------+
#property copyright "AMARAL, Jorge; PAGNONCELLI, Cássio J."
#property link      "kimble9t@gmail.com"

/*
  Magic number
*/
#define MAGIC    110201

/*
  Parameters.
*/
extern string str1          = "LWMA parameter";
extern int    LWMA_period   = 500;
extern string str2          = "Money management (SL, TP, TS)";
extern int    TP_pips       = 0;
extern int    SL_pips       = 100;
extern double TP_account    = 0;
extern double SL_account    = 0.95;
extern double PositionSize  = 0.8;
extern double TS_bb_period  = 10;
extern int    TS_start_pips = 700;
extern double StopWhenLose  = 0.8;
extern string   str3        = "Time filter";
extern bool ApplyTimeFilter = false;
extern int      GMT_server  = 3;
extern datetime StartTime   = D'1970.01.01 00:00';
extern datetime EndTime     = D'1970.01.01 13:00';

/*
  Signals.
*/
#define STAND   0
#define LONG    1
#define SHORT  -1

/*
  Global vars.
*/
double pip;
bool start_allowed, maximum_equity, initial_equity;

/*
  init, deinit, and main.
*/
int init()
{
  /* set pip size. */
  pip = Point;
  if (Digits == 3 || Digits == 5)
    pip *= 10;
  
  /* check parameters. */
  start_allowed = true;
  if (LWMA_period < 1)
    start_allowed = false;
  if (TP_pips < 0)
    start_allowed = false;
  if (SL_pips < 0)
    start_allowed = false;
  if (TP_account <= 1 && TP_account != 0)
    start_allowed = false;
  if (SL_account < 0 || SL_account > 1)
    start_allowed = false;
  if (PositionSize < 0 || 1 < PositionSize)
    start_allowed = false;
  
  /* initial conditions satisfied. */
  if (!start_allowed)
    Print("One or more parameters are not valid. Please, check your parameters before continuing.");
  
  /* symbol names. */
  if (StringLen(Symbol()) != 6) {
    start_allowed = false;
    Print("Symbol names don't have 6 characters. Try changing data feed.");
  }
  
  /* check whether <base><currency> rate can be found. */
  if (base_currency() == 0.0) {
    start_allowed = false;
    Print("Can't calculate optimal position size for this instrument. Trades will not be allowed for this instrument.");
  }
  
  maximum_equity = AccountEquity();
  initial_equity = AccountEquity();
  
  return (0);
}

int deinit()
{
  return (0);
}

int start()
{
  if (!start_allowed)
    return (0);
  
  /* mono-position EA. */
  int signal = check_signal();
  manage_positions(signal);
  handle_signal(signal);
  
  /* update vars */
  maximum_equity = MathMax(maximum_equity, AccountEquity());
  
  return (0);
}

/*
   DESCRIPTION
     Check time for trading.
   
   RETURN
     True iff current server's time is between `StartTime' and `EndTime',
     the allowed time to trade.
 */
bool TimeFilter()
{
  if (!ApplyTimeFilter)
    return (true);
  
  datetime
    horario_inicio = StartTime,
    horario_fim    = EndTime;
  
  /*
    Using this function from my ``3MM.mq4'' expert.
  */
  int
    hora_atual    = (TimeHour(TimeCurrent()) + GMT_server) % 24,
    minuto_atual  = TimeMinute(TimeCurrent());
  
  if (TimeHour(horario_inicio) < TimeHour(horario_fim) 
    || (TimeHour(horario_inicio) && TimeHour(horario_fim) 
        && TimeMinute(horario_inicio) <= TimeMinute(horario_fim)))
    return ( // horario_inicio <= horario_atual <= horario_fim
      (
        TimeHour(horario_inicio) < hora_atual || 
        (TimeHour(horario_inicio) == hora_atual && TimeMinute(horario_inicio) <= minuto_atual)
      )
      &&
      (
        hora_atual < TimeHour(horario_fim) || 
        (hora_atual == TimeHour(horario_fim) && minuto_atual <= TimeMinute(horario_fim))
      )
    );
  else
    return ( // horario_atual <= horario_fim  ou  horario_inicio <= horario_atual
      (
        hora_atual < TimeHour(horario_fim) || 
        (hora_atual == TimeHour(horario_fim) && minuto_atual <= TimeMinute(horario_fim))
      )
      ||
      (
        TimeHour(horario_inicio) < hora_atual || 
        (TimeHour(horario_inicio) == hora_atual && TimeMinute(horario_inicio) <= minuto_atual)
      )
    );
}

/*
   DESCRIPTION
     Handle a signal by opening or not new positions.
*/
void handle_signal(int signal)
{
  if (signal == STAND)
    return;
  
  switch (signal) {
  case LONG:
    buy();  /* must be an atomic operation. */
    break;
  case SHORT:
    sell(); /* must be an atomic operation. */
    break;
  }
}

/*
   DESCRIPTION
     Checks for a new market signal.

   RETURN
      LONG, whenever close[1] > upper lwma > open[1];
     SHORT, whenever close[1] < lower lwma < open[1];
     STAND, converse case.
 */
int check_signal()
{
   double
     upper = iMA(Symbol(), 0, LWMA_period, 0, MODE_LWMA, PRICE_HIGH, 1),
     lower = iMA(Symbol(), 0, LWMA_period, 0, MODE_LWMA,  PRICE_LOW, 1);
   
   /* check for going long. */
   if (Close[1] > upper && upper > Open[1])
     return (LONG);
   
   /* check for going short. */
   if (Close[1] < lower && lower < Open[1])
     return (SHORT);
   
   /* no entry signal */
   return (STAND);
}

/*
   Order management.
   
   DESCRIPTION
     Send `buy' and `sell' orders to entry long/short positions.
   
   RETURN
     True iff a position was established.
*/
bool buy()
{
  // time filter
  if (!TimeFilter()) return (false);
  
  // maximum equity check
  if (AccountEquity() / maximum_equity < 1 - StopWhenLose) {
    start_allowed = false;
    return (false);
  }
  
  // size of the position
  double s = position_sizing();
  if (s < MarketInfo(Symbol(), MODE_MINLOT)) return (false);
  
  // send order
  bool ret = true;
  double max = MarketInfo(Symbol(), MODE_MAXLOT);
  for (int i=1; i<=MathCeil(s / max); i++) {
    ret = ret && (OrderSend(Symbol(), OP_BUY, MathMin(max, s), Ask, 2, sl(OP_BUY), tp(OP_BUY)) > 0);
    s -= MathMin(max, s);
  }
  
  return (ret);
}

bool sell()
{
  // time filter
  if (!TimeFilter()) return (false);
  
  // maximum equity check
  if (AccountEquity() / maximum_equity < 1 - StopWhenLose) {
    start_allowed = false;
    return (false);
  }
  
  // size of the position
  double s = position_sizing();
  if (s < MarketInfo(Symbol(), MODE_MINLOT)) return (false);
  
  // send order
  bool ret = true;
  double max = MarketInfo(Symbol(), MODE_MAXLOT);
  for (int i=1; i<=MathCeil(s / max); i++) {
    ret = ret && (OrderSend(Symbol(), OP_SELL, MathMin(max, s), Bid, 2, sl(OP_SELL), tp(OP_SELL)) > 0);
    s -= MathMin(max, s);
  }
  
  return (ret);
}

/*
   TP/SL levels.
   
   DESCRIPTION
     Gets take profit and stop loss levels based on bid/ask rates (or other specified rate).
   
   RETURN
     A double representing the price.
*/
double tp(int order_type, double base_price=0)
{
  double x;
  switch (order_type) {
  case OP_BUY:
    if (base_price == 0)
      x = Ask;
    else
      x = base_price;
    
    x += TP_pips * pip;
    x = NormalizeDouble(x, Digits);
    
    if (TP_pips == 0)
      x = 0;
  case OP_SELL:
    if (base_price == 0)
      x = Bid;
    else
      x = base_price;
    
    x -= TP_pips * pip;
    x = NormalizeDouble(x, Digits);
    
    if (TP_pips == 0)
      x = 0;
  default:
    x = 0;
    break;
  }
  return (x);
}

double sl(int order_type, double base_price=0)
{
  double x;
  switch (order_type) {
  case OP_BUY:
    if (base_price == 0)
      x = Ask;
    else
      x = base_price;
    
    x -= SL_pips * pip;
    x = NormalizeDouble(x, Digits);
    
    if (SL_pips == 0)
      x = 0;
  case OP_SELL:
    if (base_price == 0)
      x = Bid;
    else
      x = base_price;
    
    x += SL_pips * pip;
    x = NormalizeDouble(x, Digits);
    
    if (SL_pips == 0)
      x = 0;
  default:
    x = 0;
    break;
  }
  return (x);
}

/*
   DESCRIPTION
     Closes all opened positions.
   
   RETURN
     True iff there is no opened position.
*/
bool close_all()
{
  double p;
  for (int i=0; i<OrdersTotal(); i++) {
    if (OrderSelect(i, SELECT_BY_POS)) {
      // define close price
      if (OrderType() == OP_BUY)
        p = Bid;
      else
        p = Ask;
      
      OrderClose(OrderTicket(), OrderLots(), p, 1);
    } else
      i--;
  }
  
  return (OrdersTotal() == 0);
}

/*
   DESCRIPTION
     Calculates position sizing.
   
   RETURN
     A double in two-decimals.
*/
double position_sizing()
{
  return (NormalizeDouble(
    PositionSize * 
      (AccountEquity() * (NormalizeDouble(AccountLeverage(), 1) - 2.0) / NormalizeDouble(MarketInfo(Symbol(), MODE_LOTSIZE), 1))
      / base_currency(),
    MathLog(1 / MarketInfo(Symbol(), MODE_MINLOT)))
  );
}

/*
   DESCRIPTION
     Look ahead for <base><currency> quote.
   
   RETURN
     A double (>0), indicating the price;
     0, otherwise.
*/
double base_currency()
{
  string
    base = StringSubstr(Symbol(), 0, 3),
    quot = StringSubstr(Symbol(), 3, 3),
    curr = AccountCurrency();
  
  // account currency in the same instrument
  if (base == curr) return (1.0);
  if (quot == curr) return (Ask);
  
  // not in the same instrument
  if (MarketInfo(StringConcatenate(base, curr), MODE_ASK) > 0)
    return (MarketInfo(StringConcatenate(base, curr), MODE_ASK));
  if (MarketInfo(StringConcatenate(curr, base), MODE_ASK) > 0)
    return (1 / MarketInfo(StringConcatenate(curr, base), MODE_ASK));
  
  // instrument not found
  start_allowed = false;
  return (0.0);
}

/*
   DESCRIPTION
     Manages all opened positions.
*/
void manage_positions(int signal)
{
  double pl = AccountEquity() / AccountBalance();
  if ((SL_account != 0 && pl < SL_account) || (TP_account != 0 && TP_account < pl))
    close_all();
  
  if (AccountEquity() / maximum_equity < 1 - StopWhenLose || AccountEquity() / initial_equity > 200) {
    close_all();
    start_allowed = false;
  }
   
   // close positions against signal
  int i;
  switch (signal) {
  case LONG:
    for (i=0; i<OrdersTotal(); i++)
      if (OrderSelect(i, SELECT_BY_POS) && OrderType() == OP_SELL)
        OrderClose(OrderTicket(), OrderLots(), Ask, 2);
    break;
  case SHORT:
    for (i=0; i<OrdersTotal(); i++)
      if (OrderSelect(i, SELECT_BY_POS) && OrderType() == OP_BUY)
         OrderClose(OrderTicket(), OrderLots(), Bid, 2);
    break;
  case STAND:
    break;
  default:
    break;
  }
    
  // adjust trailing stops
  for (i=0; i<OrdersTotal(); i++)
    if (OrderSelect(i, SELECT_BY_POS))
      adjust_ts(OrderType());
}

/*
  DESCRIPTION
    Manages trailing stop for the selected position.
    (Assumes an opened position is selected.)
  
  RETURN
    True iff no error has occurred.
*/
bool adjust_ts(int order_type)
{
  /* trailing stop disabled. */
  if (TS_start_pips == 0)
    return;

  double
    start,    /* start price. */
    sl,       /* stop loss level. */
    ts;       /* new stop loss. */
  
  switch (order_type) {
  case OP_BUY:
    start = OrderOpenPrice() + TS_start_pips * pip;
    if (Bid < start) return;
    
    sl = OrderStopLoss();
    if (sl != 0 && Bid < sl) return;
    
    ts = NormalizeDouble(iBands(Symbol(), 0, TS_bb_period, 1, 0, PRICE_CLOSE, MODE_LOWER, 0), 5);
    if (ts < start) return;
    if (sl != 0 && ts <= sl) return;
    if (ts >= Bid - MarketInfo(Symbol(), MODE_FREEZELEVEL) * Point) return;
    
    return (OrderModify(OrderTicket(), OrderOpenPrice(), ts, OrderTakeProfit(), OrderExpiration()));
    break;
  case OP_SELL:
    start = OrderOpenPrice() - TS_start_pips * pip;
    if (Ask > start) return;
    
    sl = OrderStopLoss();
    if (sl != 0 && Ask > sl) return;
    
    ts = NormalizeDouble(iBands(Symbol(), 0, TS_bb_period, 1, 0, PRICE_CLOSE, MODE_UPPER, 0), 5);
    if (ts > start) return;
    if (sl != 0 && ts >= sl) return;
    if (ts <= Ask + MarketInfo(Symbol(), MODE_FREEZELEVEL) * Point) return;
    
    return (OrderModify(OrderTicket(), OrderOpenPrice(), ts, OrderTakeProfit(), OrderExpiration()));
    break;
  }
}