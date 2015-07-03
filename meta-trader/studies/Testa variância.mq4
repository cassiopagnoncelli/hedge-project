//+------------------------------------------------------------------+
//|                                              Testa variância.mq4 |
//|                                        Cássio Jandir Pagnoncelli |
//|                                            ww.inf.ufpr.br/~cjp07 |
//+------------------------------------------------------------------+
#property copyright "Cássio Jandir Pagnoncelli"
#property link      "ww.inf.ufpr.br/~cjp07"

/* número de altas/baixas de `index' pips consecutivos */
int altas[200], baixas[200];

/* registro dos dois ultimos bids */
double bid0, bid1;

/* numero de pips ascendentes/descendentes consecutivos da alta/baixa */
int i;

/* direcao (alta/baixa) atual */
int dir;

/* datas das maximas */
datetime dupper, dlower;
int upper_pips, lower_pips;


int init() {
   ArrayInitialize(altas, 0);
   ArrayInitialize(baixas, 0);
   
   bid0 = Bid;
   bid1 = Bid;
   
   dir = MODE_LOWER;
   
   i = 0;
   
   dupper = 0;
   dlower = 0;
   upper_pips = 0;
   lower_pips = 0;
   
   return(0);
}

int start() {
   if (Bid != bid1) {
      bid0 = bid1;
      bid1 = Bid;
      
      if (bid1 < bid0) {
         if (dir == MODE_LOWER) {
            i++;
            if (i > lower_pips) {
               lower_pips = i;
               dlower = TimeCurrent();
            }
         } else {
            i++;
            baixas[i]++;
            i = 0;
            dir = MODE_LOWER;
         }
      } else 
      if (bid1 > bid0) {
         if (dir == MODE_UPPER) {
            i++;
            if (i > upper_pips) {
               upper_pips = i;
               dupper = TimeCurrent();
            }
         } else {
            i++;
            altas[i]++;
            i = 0;
            dir = MODE_UPPER;
         }
      }
   }
   
   return(0);
}

int deinit() {
   crude_data();
   if (IsTesting()) {
      int fp = FileOpen("distr_altas_baixas_pips.dat", FILE_WRITE|FILE_BIN);
      if (fp > 0) {
         // altas
         for (int max=200-1; max>0 && altas[max] == 0; max--) 
            continue;
         
         string str = StringConcatenate("# ALTAS (pips;qtde) [max=", max, ",data=", 
                   TimeToStr(dupper, TIME_DATE|TIME_MINUTES|TIME_SECONDS), "]\r\n");
         FileWriteString(fp, str, StringLen(str));
         for (int i=1; i<=max; i++) {
            if (altas[i] != 0)
               FileWrite(fp, i, altas[i]);
            else
               FileWriteString(fp, "...", 3);
            FileWriteString(fp, "\r\n", 2);
         }
         
         // baixas
         for (max=200-1; max>0 && baixas[max] == 0; max--) 
            continue;
         
         str = StringConcatenate("# BAIXAS (pips;qtde) [max=", max, ",data=", 
                   TimeToStr(dlower, TIME_DATE|TIME_MINUTES|TIME_SECONDS), "]\r\n");
         FileWriteString(fp, str, StringLen(str));
         for (i=1; i<=max; i++) {
            if (baixas[i] != 0)
               FileWrite(fp, i, baixas[i]);
            else
               FileWriteString(fp, "...", 3);
            FileWriteString(fp, "\r\n", 2);
         }
         
         // fechar arquivo
         FileFlush(fp);
         FileClose(fp);
      }
   }

   return(0);
}

void crude_data() {
   int fp, max, i;
   string str;
   fp = FileOpen("altas.dat", FILE_WRITE|FILE_BIN);
   if (fp > 0) {
      for (max=200-1; max>0 && altas[max] == 0; max--) continue;
      for (i=1; i<=max; i++) {
         str = StringConcatenate(i, " ", altas[i], "\r\n");
         FileWriteString(fp, str, StringLen(str));
      }
      
      FileFlush(fp);
      FileClose(fp);
   }
   
   fp = FileOpen("baixas.dat", FILE_WRITE|FILE_BIN);
   if (fp > 0) {
      for (max=200-1; max>0 && altas[max] == 0; max--) continue;
      for (i=1; i<=max; i++) {
         str = StringConcatenate(i, " ", baixas[i], "\r\n");
         FileWriteString(fp, str, StringLen(str));
      }
      
      FileFlush(fp);
      FileClose(fp);
   }
}