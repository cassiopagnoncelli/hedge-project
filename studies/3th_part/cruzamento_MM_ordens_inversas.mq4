//+------------------------------------------------------------------+
//|                                                Cruzamento_MM.mq4 |
//|                André Duarte de Novais, Cássio Jandir Pagnoncelli |
//|                                          www.inf.ufpr.br/~cjp07/ |
//+------------------------------------------------------------------+
#property copyright "André Duarte de Novais, Cássio Jandir Pagnoncelli"

//+------------------------------------------------------------------+
// AVISO: Este EA foi desenvolvido com o intuito para rodar na 
// periodicidade de H4.
//+------------------------------------------------------------------+

// Parâmetros
extern int       Periodicidade_MME_Lenta     = 21; //377
extern int       Periodicidade_MME_Rapida    = 5;
extern double    Tamanho_do_lote_basico      = 1;
extern double    TAKE_PROFIT                 = 38; //34 ou 61 ou 120
extern double    STOP_LOSS                   = 110; //89 ou 30
extern double    Deposito_Inicial            = 10000.0;

double MA_rapida, MA_lenta, pip;
bool rapida_acima_da_lenta_ANTERIOR, rapida_acima_da_lenta;
int ultimo_ticket;

int init() {
     ultimo_ticket = 0;
     pip = 0.0001;

     // Guarda o estado das MME (qual esta por cima)
     MA_rapida = iMA(Symbol(), 0, Periodicidade_MME_Rapida, 0, MODE_EMA, PRICE_TYPICAL, 0);
     MA_lenta  = iMA(Symbol(), 0, Periodicidade_MME_Lenta, 0, MODE_EMA, PRICE_TYPICAL, 0);  
     if ( MA_rapida > MA_lenta ) 
          rapida_acima_da_lenta_ANTERIOR = true;
     else 
          rapida_acima_da_lenta_ANTERIOR = false;
     
     return (0);
}

int deinit(){ 
     Alert(AccountEquity()/Deposito_Inicial);
     return (0);
}

int start() {
     // Valor das MME no tick atual
     MA_rapida = iMA(Symbol(), 0, Periodicidade_MME_Rapida, 0, MODE_EMA, PRICE_TYPICAL, 0);
     MA_lenta  = iMA(Symbol(), 0, Periodicidade_MME_Lenta, 0, MODE_EMA, PRICE_TYPICAL, 0);
     
     // Verifica qual MME está por cima
     if ( MA_rapida > MA_lenta ) 
          rapida_acima_da_lenta = true;
     else 
          rapida_acima_da_lenta = false;

     // Realiza operacoes nos cruzamentos das MME
     if ( rapida_acima_da_lenta_ANTERIOR && !rapida_acima_da_lenta ) // MMs se cruzaram
          ultimo_ticket = encerra_e_compra(Tamanho_do_lote_basico * lote_carteira());
     else if ( !rapida_acima_da_lenta_ANTERIOR && rapida_acima_da_lenta ) // MMs se cruzaram no sentido oposto
          ultimo_ticket = encerra_e_vende(Tamanho_do_lote_basico * lote_carteira());

     // Guarda o estado de alinhamento das MME pra ser usado no ticket seguinte
     rapida_acima_da_lenta_ANTERIOR = rapida_acima_da_lenta;
     
     return (0);
}

// Encerra a posicao de venda e realiza uma compra
int encerra_e_compra(double lote) {
     if ( ultimo_ticket != 0 ) 
          OrderClose(ultimo_ticket, lote, Ask, 0); 
          
     if ( STOP_LOSS == 0 && TAKE_PROFIT == 0 )
          return (OrderSend(Symbol(), OP_BUY, lote, Ask, 0, 0, 0)); 
     else if ( STOP_LOSS == 0 ) 
          return (OrderSend(Symbol(), OP_BUY, lote, Ask, 0, 0, Ask + TAKE_PROFIT * pip)); 
     else if ( TAKE_PROFIT == 0 )
          return (OrderSend(Symbol(), OP_BUY, lote, Ask, 0, Ask - STOP_LOSS * pip, 0)); 
     else
          return (OrderSend(Symbol(), OP_BUY, lote, Ask, 0, Ask - STOP_LOSS * pip, Ask + TAKE_PROFIT * pip)); 
}

// Encerra a posicao de compra e realiza uma venda a descoberto
int encerra_e_vende(double lote) {
     if ( ultimo_ticket != 0 )
          OrderClose(ultimo_ticket, lote, Bid, 0);
     
     if ( STOP_LOSS == 0 && TAKE_PROFIT == 0 )
          return (OrderSend(Symbol(), OP_SELL, lote, Bid, 0, 0, Bid - TAKE_PROFIT * pip));
     else if ( STOP_LOSS == 0 )
          return (OrderSend(Symbol(), OP_SELL, lote, Bid, 0, 0, Bid - TAKE_PROFIT * pip));
     else if ( TAKE_PROFIT == 0 )
          return (OrderSend(Symbol(), OP_SELL, lote, Bid, 0, Bid + STOP_LOSS * pip, 0));
     else
          return (OrderSend(Symbol(), OP_SELL, lote, Bid, 0, Bid + STOP_LOSS * pip, Bid - TAKE_PROFIT * pip));
}

double lote_carteira() {
     //if ( AccountEquity()/10000.0 > 1 ) 
     //     return (MathPow(AccountEquity()/10000.0*(0.5), 2.71));
     //else
     //     return (1);
     double indice_lucro = AccountEquity()/Deposito_Inicial;
     return (MathPow(MathExp(0.8), indice_lucro*(1)));
}

double angulo(double close_anterior, double open_anterior, double close_atual, double open_atual) {
     return ( (close_anterior*close_atual) / (open_anterior*open_atual) );
}