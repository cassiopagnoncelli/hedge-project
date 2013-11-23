//+------------------------------------------------------------------+
//|                                                          DMM.mq4 |
//|                                        Cássio Jandir Pagnoncelli |
//|                                     http://www.inf.ufpr.br/cjp07 |
//+------------------------------------------------------------------+
#property copyright "Cássio Jandir Pagnoncelli"
#property link      "http://www.inf.ufpr.br/cjp07"
#define versao "0.1"

/* propriedades visuais do expert. */
#property indicator_separate_window
#property indicator_buffers 2
#property indicator_color1 Silver
#property indicator_width1 2
#property indicator_color2 Red

/* parâmetros. */
extern int PeriodoMM        = 15;
extern int PeriodoRegressao = 7;
extern int LinhaSinal       = 4;

/* buffers. */
double histograma[], sinal[];

/* init, deinit, start. */
int init()
{
  SetIndexStyle(0, DRAW_HISTOGRAM);
  SetIndexStyle(1, DRAW_LINE);
  SetIndexDrawBegin(1, sinal);
  IndicatorDigits(Digits+1);

  SetIndexBuffer(0, histograma);
  SetIndexBuffer(1, sinal);
  
  IndicatorShortName("RegressaoMMCD(" + PeriodoMM + "," + PeriodoRegressao + "," + LinhaSinal + ")");
  SetIndexLabel(0, "RegressaoMMCD");
  SetIndexLabel(1, "Linha de Sinal");
  
  return(0);
}

int deinit()
{
  return(0);
}

int start()
{
  int counted_bars = IndicatorCounted();
  if(counted_bars > 0)
    counted_bars--;
  
  int limite = Bars - counted_bars;
  
  // histograma
  for(int i=0; i<limite; i++)
    histograma[i] = MathArctan(iCustom(Symbol(), 0, "MM_inclinacao", 
      PeriodoRegressao, PeriodoMM, false, 1, 40, 2, 0,
      0, i));
  
  // sinal
  for(i=0; i<limite; i++)
    sinal[i] = iMAOnArray(histograma, Bars, LinhaSinal, 0, MODE_SMA, i);
  
  return(0);
}
