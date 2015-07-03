//+------------------------------------------------------------------+
//|                                                MM_inclinacao.mq4 |
//|                Andr� Duarte de Novais, C�ssio Jandir Pagnoncelli |
//|                                     http://www.inf.ufpr.br/cjp07 |
//+------------------------------------------------------------------+
#property copyright "Andr� Duarte de Novais, C�ssio Jandir Pagnoncelli"
#property link      "http://www.inf.ufpr.br/cjp07"
#property indicator_chart_window
#define versao "1.0"

/* par�metros. */
// configura��o da reta
extern int   Periodo      = 10;
extern int   PeriodoMM    = 30;
// desenho
extern bool  DesenharReta = true;
extern int   LinhaID      = 0;
extern color LinhaCor     = Red;
extern int   LinhaLargura = 1;
// shift
extern int   Shift        = 0;

/* buffers exportados */
double A[1], B[1];

/* init, deinit, start. */
void
init()
{
  IndicatorShortName("MM_inclinacao(periodo=" + Periodo + ",mm=" + PeriodoMM + ")");
  IndicatorBuffers(2);
  SetIndexBuffer(0, A);
  SetIndexBuffer(1, B);
  
  return(0);
}

int
deinit()
{
  if (DesenharReta)
    ObjectDelete("MM_inclinacao-" + LinhaID);
  
  return(0);
}

int
start()
{
  // dados da m�dia m�vel: (i, mm(i)), para i = 1, ..., periodo.
  double x[], y[];
  ArrayResize(x, Periodo); ArrayResize(y, Periodo);
  for (int i=0; i<Periodo; i++) {
    x[i] = i + 1;
    y[i] = iMA(Symbol(), Period(), PeriodoMM, i+1, MODE_SMA, PRICE_CLOSE, Shift);
  }
  
  double // ser�o estimados par�metros de uma fun��o de primeiro grau
    a = estima_a(x, y),
    b = estima_b(x, y);
  
  /* exporta os par�metros estimados */
  A[0] = a;
  B[0] = b;
  
  // Desenha linha
  if (DesenharReta)
  {
    if (ObjectFind("MM_inclinacao-" + LinhaID) != -1)
      ObjectDelete("MM_inclinacao-" + LinhaID);
  
    if (!ObjectCreate("MM_inclinacao-" + LinhaID, OBJ_TREND, 0, Time[Periodo + 1 + Shift],
                      f(Periodo + 1, a, b), Time[1 + Shift], f(1, a, b)))
      Print("N�o consegui tra�ar a reta de regress�o sobre a m�dia m�vel.");
    else {
      ObjectSet("MM_inclinacao-" + LinhaID, OBJPROP_COLOR, LinhaCor);
      ObjectSet("MM_inclinacao-" + LinhaID, OBJPROP_WIDTH, LinhaLargura);
    }
  }
  
  return(0);
}

/* fun��o de estimativa */
double
f(double x, double a, double b)
{
  return (a * x + b);
}

/* estat�sticas suficientes: media e produto interno */
double
media(double v[])
{
  double m = 0;
  for (int i=0; i<Periodo; i++)
    m += v[i];
  return (m / Periodo);
}

double
prod_interno(double u[], double v[])
{
  if (ArraySize(u) != ArraySize(v))
    return (0);
  
  double pi = 0;
  for (int i=0; i<Periodo; i++)
    pi += u[i] * v[i];
  return (pi);
}

/* m�nimos quadrados linear (ax+b=y), com os estimadores de `a' e `b'. */
double
estima_a(double x[], double y[])
{
  if (ArraySize(x) != ArraySize(y))
    return (0);

  double 
    media_x = media(x);
  
  double
    numerador = prod_interno(x, y) - Periodo * media_x * media(y),
    denominador = prod_interno(x, x) - Periodo * media_x * media_x;
  
  return (numerador / denominador);
}

double
estima_b(double x[], double y[])
{
  if (ArraySize(x) != ArraySize(y))
    return (0);

  double
    media_x = media(x),
    pi_xx = prod_interno(x, x);
  
  double
    numerador = media(y) * pi_xx - media_x * prod_interno(x, y),
    denominador = pi_xx - Periodo * media_x * media_x;
  
  return (numerador / denominador);
}
