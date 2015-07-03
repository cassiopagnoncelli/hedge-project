//+------------------------------------------------------------------+
//|                                             Max_low_Max_high.mq4 |
//|                                        Cássio Jandir Pagnoncelli |
//|                                          www.inf.ufpr.br/~cjp07/ |
//+------------------------------------------------------------------+
#property copyright "Cássio Jandir Pagnoncelli"
#property link      "www.inf.ufpr.br/~cjp07/"

int candles_alta, candles_baixa, alta_local, baixa_local;
datetime data_alta, data_baixa;

int init() {
     candles_alta = 0;
     candles_baixa = 0;
     alta_local = 0;
     baixa_local = 0;
     
     return (0);
}

int deinit() {
    Alert(StringConcatenate("Alta: ", candles_alta, " candles, terminado em ", imprime_data(data_alta)));
    Alert(StringConcatenate("Baixa: ", candles_baixa, " candles, terminado em ", imprime_data(data_baixa)));
    return (0);
}

int start() {
     if ( Close[0] > Close[1] ) { 
          baixa_local = 0;
          alta_local++;
          if ( alta_local >= candles_alta ) {
               candles_alta = alta_local; 
               data_alta = TimeCurrent();
          }
     } else if ( Close[0] < Close[1] ) { 
          alta_local = 0;
          baixa_local++;
          if ( baixa_local >= candles_baixa ) {
               candles_baixa = baixa_local;
               data_baixa = TimeCurrent();
          }
     } 
     
     return (0);
}

string imprime_data(datetime dt) {
     string data = StringConcatenate(   TimeDay(dt),    "/",
                                        TimeMonth(dt) , "/" ,
                                        TimeYear(dt),   " ",
                                        TimeHour(dt),   ":" ,
                                        TimeMinute(dt), ":" ,
                                        TimeSeconds(dt)
                                     );
     return (data);
}
