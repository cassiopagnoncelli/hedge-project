//+------------------------------------------------------------------+
//|                                        macd_venda_descoberto.mq4 |
//|                                        Cássio Jandir Pagnoncelli |
//|                                          www.inf.ufpr.br/~cjp07/ |
//+------------------------------------------------------------------+
#property copyright "Cássio Jandir Pagnoncelli"
#property link      "www.inf.ufpr.br/~cjp07/"

//---- input parameters
extern int       MACD_EMM_SLOW = 380;
extern int       MACD_EMM_FAST = 63;
extern int       MACD_SMA      = 1;
extern double    LOT_SIZE      = 0.2;
extern int       STOP_LOSS     = 80;
extern int       TAKE_PROFIT   = 90;

double    PIP           = 0.0001;
double    MACD_lim_sup = 0.0022,
          MACD_lim_inf = 0.0014,
          macd_atual, macd_fila[15] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
int       macd_fila_tam = 0;
bool      tendencia_convergencia;

int init() {
     return (0);
}

int deinit() {
     return (0);     
}

int start() {
     macd_atual = iMACD(Symbol(), 0, MACD_EMM_FAST, MACD_EMM_SLOW, MACD_SMA, PRICE_TYPICAL, MODE_SIGNAL, 0);
     if (macd_atual > MACD_lim_sup) tendencia_convergencia = true;
     if (macd_atual < MACD_lim_inf) tendencia_convergencia = false;
     if (macd_atual > MACD_lim_sup || macd_atual < MACD_lim_inf) return (0);
     enfila(macd_atual);
     if (!MM_convergindo()) return (0);
   
     OrderSend(Symbol(), OP_SELL, LOT_SIZE, Bid, 0, Bid + STOP_LOSS*PIP, Bid - TAKE_PROFIT*PIP);
     
     return (0);
}

// Evita sinais falsos ao iniciar o EA
void enfila(double macd_val) {
     int i;
     for ( i=0; i<macd_fila_tam-1; i++ )
          macd_fila[i] = macd_fila[i+1];
     macd_fila[i] = macd_val;

     if ( macd_fila_tam < 15 )
          macd_fila_tam++;
}

// Verifica se as medias moveis estao convergindo
bool MM_convergindo() {
     int i;
     for ( i=0; i<macd_fila_tam; i++ ) 
          if ( macd_fila[i] < MACD_lim_inf )
               return (false);
     
     if ( !tendencia_convergencia ) return (false);
     
     return (true);
}
