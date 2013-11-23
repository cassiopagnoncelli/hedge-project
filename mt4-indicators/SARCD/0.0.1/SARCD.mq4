//+------------------------------------------------------------------+
//|                                                        SARCD.mq4 |
//|                                        Cássio Jandir Pagnoncelli |
//|                                     http://www.inf.ufpr.br/cjp07 |
//+------------------------------------------------------------------+
#property copyright "Cássio Jandir Pagnoncelli"
#property link      "http://www.inf.ufpr.br/cjp07"
#define versao "0.0.1"

#property indicator_separate_window
#property  indicator_buffers 2
#property  indicator_color1  Silver
#property  indicator_color2  Red
#property  indicator_width1  2

/* parâmetros. */
extern double psar_step = 0.0007;
extern double psar_max  = 0.002;
extern int    SignalSMA = 8;

/* buffers. */
double     PSCDBuffer[];
double     SignalBuffer[];

/* init, deinit, start */
int init()
{
  // drawing settings
  SetIndexStyle(0,DRAW_HISTOGRAM);
  SetIndexStyle(1,DRAW_LINE);
  SetIndexDrawBegin(1, SignalSMA);
  IndicatorDigits(Digits+1);
   
  // indicator buffers mapping
  SetIndexBuffer(0, PSCDBuffer);
  SetIndexBuffer(1, SignalBuffer);
   
  //---- name for DataWindow and indicator subwindow label
  IndicatorShortName("PSCD(step="+psar_step+",max="+psar_max+")");
  SetIndexLabel(0,"PSCD");
  SetIndexLabel(1,"Signal");
  
  return(0);
}

int deinit()
{}

int start()
{
  int limit;
  int counted_bars=IndicatorCounted();
  
  // last counted bar will be recounted
  if(counted_bars>0) 
    counted_bars--;
  limit=Bars-counted_bars;
   
  //---- macd counted in the 1-st buffer
  for(int i=0; i<limit; i++)
    PSCDBuffer[i] = iSAR(Symbol(), Period(), psar_step, psar_max, i) - High[i];
  
  //---- signal line counted in the 2-nd buffer
  for(i=0; i<limit; i++)
    SignalBuffer[i] = iMAOnArray(PSCDBuffer, Bars, SignalSMA, 0, MODE_SMA, i);
   
  return(0);
}
