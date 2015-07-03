//+------------------------------------------------------------------+
//|                                                  ComprasPSAR.mq4 |
//|                                        Cássio Jandir Pagnoncelli |
//|                                          www.inf.ufpr.br/~cjp07/ |
//+------------------------------------------------------------------+
#property copyright "Cássio Jandir Pagnoncelli"
#property link      "www.inf.ufpr.br/~cjp07/"

extern double passo = 0.02, max = 0.2;

int ultimo_ticket = 0;
double lote = 0.01;
bool psar_acima, comprado;
double psar;

int init() {
//     passo = 0.06;
//     max = 0.15;
     
     psar = iSAR(Symbol(), 0, passo, max, 0); 
     if ( psar > Ask ) psar_acima = true;
     else psar_acima = false;
     
     comprado = false;
     
     return (0);
}

int deinit() {
     return (0);
} 

int start() {
     psar = iSAR(Symbol(), 0, passo, max, 0);
     if ( psar_acima && psar < Bid )
          ultimo_ticket = encerra_e_vende();
     else if ( !psar_acima && psar > Ask )
          ultimo_ticket = encerra_e_compra();

     if ( psar > Bid ) psar_acima = true;
     else psar_acima = false;

     return (0);
}

int encerra_e_compra() {
     if ( ultimo_ticket != 0 ) 
          OrderClose(ultimo_ticket, lote, Ask, 0); 
     return (OrderSend(Symbol(), OP_BUY, lote, Ask, 0, 0, 0)); 
}

int encerra_e_vende() {
     if ( ultimo_ticket != 0 )
          OrderClose(ultimo_ticket, lote, Bid, 0);
     return (OrderSend(Symbol(), OP_SELL,lote, Bid, 0, 0, 0));
}