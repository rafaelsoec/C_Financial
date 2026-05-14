//+------------------------------------------------------------------+
//|                                          FamilyMJ_MultiTF.mq5    |
//+------------------------------------------------------------------+
#property strict

#include <Trade/Trade.mqh>

struct BordersOperation {
   double max;
   double min;
   double central;
   bool instantiated;
};

enum LEVEL{
   L1,
   L2,
   L3
 };
 
enum TYPE_NEGOCIATION{
   BUY,
   SELL,
   NONE
};



CTrade trade;

struct TimeframeConfig
{
   ENUM_TIMEFRAMES tf;
   int tfSeconds;
   int cciHandle;
   int maxRobots;
   int maxRobotsHighRisk;
   double multiplier;
   datetime lastBarTime;
   bool waitNewCandle;
   bool waitNewCandleHighRisk;
   bool enableTendency;
   bool enableInversion;
   ulong magicNumber;
   TYPE_NEGOCIATION signalReversao;
   TYPE_NEGOCIATION signalTendencia;
   TYPE_NEGOCIATION actualTendency;
   string label;
   MqlRates candleCandidate;
   MqlRates lastCandleCandidate;
   int candleCandidateCounter;
   TYPE_NEGOCIATION candleCandidateTendency;
};

struct MaximosMinimos
{
   double high;
   double low;
   double minOpen;
   double maxOpen;
   double minClose;
   double maxClose;
};


input double VOLUME = 0.01;
input double PERCENT_LOSS_PER_DAY = 2;
input double PERCENTUAL_MOVE_STOP = 40;
input double PERCENTUAL_ACCEPTABLE_CANDLE_BODY = 70;
input int QTD_CANDLES = 5;
 input bool ENABLE_ENGOLFO = true;
 bool ENABLE_MULTI_ROBOTS_IN_PROFIT = false;
input bool ENABLE_TIMEFRAME_MULTIPLIER = true;
 bool DISABLED_SECONDARY_VALIDATIONS = true;
 bool DISABLED_LATERAL_MARKET_VALIDATIONS = true;
input bool DISABLED_ADX_SIZE_VALIDATIONS = true;
input bool ENABLE_SWING_TRADE = true;
input int NUMBER_MAX_ROBOT = 10;
input bool IS_TEST = false;

 int NUMBER_MAX_ROBOT_BY_TIMEFRAME = 3;
 
double BALANCE = 0;
double COUNTER_LOSS = 0, COUNTER_PROFIT = 0;
ulong MAGIC_NUMBER = 97889902933;

TimeframeConfig configs[];
string labelName = "CandleTimer";
MqlRates candles[];
MqlTick tick;        
int countOrders = 0;
bool countCycles = false;
double VALUE_MOVING_AVERAGE[3], VALUE_MOVING_AVERAGE21[3], VALUE_ADX[3], VALUE_CCI[3], PROPORTION_TAKE_STOP = 2;
int MIN_COUNT_CANDIDATE_CANDLE = 5, BUY_COUNT = 0, SELL_COUNT = 0;


//+------------------------------------------------------------------+
ulong GetMagicNumberByTimeframe(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      default:         return MAGIC_NUMBER;
   }
}


//+------------------------------------------------------------------+
void showComments(){
   double profit = AccountInfoDouble(ACCOUNT_PROFIT);
   Comment(
         " Total de posições ativas: ", (countOrders), 
         " Saldo: ", DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE) + profit, 2),
         " Lucro Atual: ", DoubleToString(profit, 2),
         " Tempo de Candle: ", transformarCandleTime()
         );
}

double TimeframeToMultiplier(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M5: return 1;
      case PERIOD_M10: return 1;
      case PERIOD_M15: return 1.2;
      case PERIOD_M20: return 1.5;
      case PERIOD_M30: return 2;
      case PERIOD_H1:  return 2.5;
      case PERIOD_H2:  return 3;
      case PERIOD_H3:  return 3.5;
      case PERIOD_H4:  return 4;
      case PERIOD_H6:  return 4.5;
      case PERIOD_H8:  return 5;
      case PERIOD_D1:  return 5.5;
      case PERIOD_W1:  return 6;
      case PERIOD_MN1:  return 6.5;
      default:         return 1;
   }
}

int TimeframeToSeconds(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M5: return 5 * 60;
      case PERIOD_M10: return 10 * 60;
      case PERIOD_M15: return 15 * 60;
      case PERIOD_M20: return 20 * 60;
      case PERIOD_M30: return 30 * 60;
      case PERIOD_H1:  return 60 * 60;
      case PERIOD_H2:  return 2 * 60 * 60;
      case PERIOD_H3:  return 3 * 60 * 60;
      case PERIOD_H4:  return 4 * 60 * 60;
      case PERIOD_H6:  return 6 * 60 * 60;
      case PERIOD_H8:  return 8 * 60 * 60;
      case PERIOD_D1:  return 24 * 60 * 60;
      case PERIOD_W1:  return 30 * 24 * 60 * 60;
      case PERIOD_MN1:  return  365 * 24 * 60 * 60;
      default:         return 0;
   }
}

//+--- NAO FUNCIONOU ESSA IDEIA---------------------------------------------------------------+
bool TimeframeToEnablePosition(ENUM_TIMEFRAMES tf, bool tendency)
{
   switch(tf)
   {
      case PERIOD_M5: return true;
      case PERIOD_M10: return true;
      case PERIOD_M15: return true;
      case PERIOD_M20: return true;
      case PERIOD_M30: return true;
      case PERIOD_H1:  return true;
      case PERIOD_H2:  return  true;
      case PERIOD_H3:  return  true;
      case PERIOD_H4:  return true;
      case PERIOD_H6:  return true;
      case PERIOD_H8:  return true;
      case PERIOD_D1:  return true;
      case PERIOD_W1:  return true;
      case PERIOD_MN1:  return true;
      default:         return true;
   }
}
//+------------------------------------------------------------------+
string TimeframeToLabel(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M5: return "M5";
      case PERIOD_M10: return "M10";
      case PERIOD_M15: return "M15";
      case PERIOD_M20: return "M20";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H2:  return "H2";
      case PERIOD_H3:  return "H3";
      case PERIOD_H4:  return "H4";
      case PERIOD_H6:  return "H6";
      case PERIOD_H8:  return "H8";
      case PERIOD_D1:  return "D1";
      case PERIOD_W1:  return "W1";
      case PERIOD_MN1:  return "MN1";
      default:         return "UNKNOWN";
   }
}

ENUM_TIMEFRAMES getTfByComment(string tfComment) {
   for(int i = 0; i < ArraySize(configs); i++) {
      string tfLabel = TimeframeToLabel(configs[i].tf);
      if(StringFind(tfComment, tfLabel) >= 0) {
         return  configs[i].tf;
      }
   }
   
   return PERIOD_MN1;
}
//+------------------------------------------------------------------+
bool IsManagedMagic(ulong magic)
{
   for(int i = 0; i < ArraySize(configs); i++)
   {
      if(configs[i].magicNumber == magic)
         return true;
   }
   return false;
}
//+------------------------------------------------------------------+
int OnInit()
{
   
   ENUM_TIMEFRAMES tfs[] = {  PERIOD_M10 , PERIOD_M15, PERIOD_M20, PERIOD_M30, PERIOD_H1, PERIOD_H2, PERIOD_H3, PERIOD_H4  };
   ArrayResize(configs, ArraySize(tfs));

   for(int i = 0; i < ArraySize(tfs); i++)
   {
      configs[i].tf = tfs[i];
      configs[i].lastBarTime = 0;
      configs[i].maxRobots = NUMBER_MAX_ROBOT_BY_TIMEFRAME;
      configs[i].multiplier = TimeframeToMultiplier(tfs[i]);
      configs[i].waitNewCandle = false;
      configs[i].actualTendency = NONE;
      configs[i].waitNewCandleHighRisk = false;
      configs[i].enableTendency = TimeframeToEnablePosition(tfs[i], true);
      configs[i].enableInversion = TimeframeToEnablePosition(tfs[i], false);
      configs[i].signalReversao = NONE;
      configs[i].signalTendencia = NONE;
      configs[i].magicNumber = GetMagicNumberByTimeframe(tfs[i]);
      configs[i].label = TimeframeToLabel(tfs[i]);
      configs[i].candleCandidateCounter = 0;
      configs[i].candleCandidateTendency = NONE;
      configs[i].tfSeconds = TimeframeToSeconds(tfs[i]);
      configs[i].maxRobotsHighRisk = NUMBER_MAX_ROBOT_BY_TIMEFRAME-1;
   }

   Print("Family MJ MultiTF iniciado com sucesso.");
   return INIT_SUCCEEDED;
}
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   for(int i = 0; i < ArraySize(configs); i++) {
      if(configs[i].cciHandle != INVALID_HANDLE)
         IndicatorRelease(configs[i].cciHandle);
   }
}
//+------------------------------------------------------------------+
void OnTick() {
   if (IsNewDay()){ 
      BALANCE = AccountInfoDouble(ACCOUNT_BALANCE);
   }
   
   if(PositionsTotal() > NUMBER_MAX_ROBOT * NUMBER_MAX_ROBOT_BY_TIMEFRAME) {
      return;
   }
   
   if(HasNewCandle(PERIOD_M1)) {
      if(!IS_TEST) {
         showComments();
         if(!ENABLE_SWING_TRADE){
   
            if(!IsMarketOpenNow(30)){
               printf("%s Mercado fechado!", _Symbol);
               closeAll();
               return; 
            }
         }
         
         COUNTER_PROFIT = 0;
         COUNTER_LOSS = 0;
         if(!CheckDailyMaxLoss(PERCENT_LOSS_PER_DAY, "USD ")) {
              printf("Perda maxima atingida.");
              closeAll();
              return;  
         }
      }
   
      if(PERCENTUAL_MOVE_STOP > 0)
         MoveStopPorPontos();
   }
  
   for(int i = 0; i < ArraySize(configs); i++)  {
      if(!GetLastClosedCandles(configs[i].tf, candles))
         return;
         
      if (!GetMovingAverage(configs[i].tf, 50 , VALUE_MOVING_AVERAGE))
         return;
         
      if (!GetAdx(configs[i].tf))
         return;
      
      if(ENABLE_ENGOLFO) {
         VerifyEngolfo(configs[i]);
      } 
         
      if(IsNewBar(configs[i])) {
         configs[i].waitNewCandle = false;
         
         if(configs[i].candleCandidateCounter > 0){
            if(configs[i].candleCandidateCounter == MIN_COUNT_CANDIDATE_CANDLE) {
               if ((configs[i].candleCandidateTendency == BUY && IsBearish(candles[1])) || (configs[i].candleCandidateTendency == SELL && IsBullish(candles[1])) ) {
                  configs[i].candleCandidateCounter = 0;
               } else {
                  configs[i].candleCandidate = candles[1];
                  configs[i].lastCandleCandidate = candles[2];                  
               }
            }
            configs[i].candleCandidateCounter--;
         }
         
         VerifyTendency(configs[i]);
          
         if(!IS_TEST)
            DeleteHorizontalLinesByPrefix(configs[i].tf);
      }  
   }
} 

bool HasNewCandle(ENUM_TIMEFRAMES timeframe){
   static datetime lastCandleTime[];

   // Inicializa array se necessário
   if(ArraySize(lastCandleTime) == 0)
   {
      ArrayResize(lastCandleTime, PERIOD_MN1 + 1);
      ArrayInitialize(lastCandleTime, 0);
   }

   datetime currentCandle = iTime(_Symbol, timeframe, 0);

   // Novo candle detectado
   if(lastCandleTime[timeframe] != currentCandle)
   {
      lastCandleTime[timeframe] = currentCandle;
      return true;
   }

   return false;
}

void DeleteHorizontalLinesByPrefix(ENUM_TIMEFRAMES labelTf) {
   int total = ObjectsTotal(0, 0, -1);

   for(int i = total - 1; i >= 0; i--) {
      string nome = ObjectName(0, i, 0, -1);
      if(nome == "") {
         continue;
      }
      
      string label = "Object_line_candleCandidato_" + EnumToString(labelTf) + "_";
      ENUM_OBJECT tipo = (ENUM_OBJECT)ObjectGetInteger(0, nome, OBJPROP_TYPE);
      if((tipo == OBJ_HLINE || tipo == OBJ_VLINE) && StringFind(nome, label) == 0) {
         string data_str = StringSubstr(nome, StringLen(label));
         datetime data = StringToTime(data_str);
         if (TimeCurrent() > data) {
            ObjectDelete(0, nome);
         }
      }
   }

   ChartRedraw();
}
void generateButtons(string signalReversao, string signalTendencia, string nome, int indice) {
   color cor = signalReversao == "COMPRA" ? clrGreen : (signalReversao == "VENDA" ? clrRed : clrOrange);
   color corT = signalTendencia == "COMPRA" ? clrGreen : (signalTendencia == "VENDA" ? clrRed : clrOrange);
   string sinal = signalReversao == "COMPRA" ? "Buy" : (signalReversao == "VENDA" ? "Sell" : "");
   string sinalT = signalTendencia == "COMPRA" ? "Buy" : (signalTendencia == "VENDA" ? "Sell" : "");

   createButton("btnButton_reversao" + signalReversao + nome, 20, (550 - indice * 50), 200, 30, CORNER_LEFT_LOWER, 11, "Arial",  " Reversao " + sinal  + nome, clrWhite, cor, cor, false);
   createButton("btnButton_tendencia" + signalTendencia + nome, 230, (550 - indice * 50), 200, 30, CORNER_LEFT_LOWER, 11, "Arial", " Tendencia " + sinalT + nome, clrWhite, corT, corT, false);
}

//+------------------------------------------------------------------+
//| Move o Stop Loss por pontos                                      |
//| pontos = distância em pontos do preço atual                      |
//+------------------------------------------------------------------+
void MoveStopPorPontos()
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   for(int i = 0; i < PositionsTotal(); i++) {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;

      if(!PositionSelectByTicket(ticket))
         continue;

      string symbol = PositionGetString(POSITION_SYMBOL);
      if(symbol != _Symbol)
         continue;

      ulong magic = (ulong)PositionGetInteger(POSITION_MAGIC);
      if(magic != MAGIC_NUMBER)
         continue;

      long type        = PositionGetInteger(POSITION_TYPE);
      double slAtual   = PositionGetDouble(POSITION_SL);
      double tpAtual   = PositionGetDouble(POSITION_TP);
      double entry     = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
      double profit = PositionGetDouble(POSITION_PROFIT);
      double volume = PositionGetDouble(POSITION_VOLUME);
      double novoSL;

      BUY_COUNT = 0;
      SELL_COUNT = 0;
      double pontosTP = calcPoints(entry, tpAtual);
      double pontosMove = pontosTP  * PERCENTUAL_MOVE_STOP / 100;
      double pontosSL = calcPoints(slAtual, currentPrice);
      double pontosEntrada = calcPoints(entry, currentPrice);
      double pontosProtecao = pontosMove * PERCENTUAL_MOVE_STOP / 100;
      
      if (profit > 0) {
         if(type == POSITION_TYPE_BUY ) {
            BUY_COUNT++;
            if (entry > slAtual) {
               if (pontosEntrada > pontosMove * 0.5) {
                  novoSL = entry + (pontosProtecao * 0.5 * point);
                  if(trade.PositionModify(ticket, novoSL, tpAtual))
                     Print("Stop movido - Protecao - ", entry, " - BUY");
               } 
            } else {
               if (pontosSL > pontosMove) {
                  novoSL = slAtual + (pontosProtecao * point);
                  if(trade.PositionModify(ticket, novoSL, tpAtual))
                     Print("Stop movido - ", novoSL, " - BUY");
               }
            }
         }
   
         if(type == POSITION_TYPE_SELL) {
            SELL_COUNT++;
            if (entry < slAtual) {
               if (pontosEntrada > pontosMove * 0.5) {
                  novoSL = entry - (pontosProtecao * 0.5 * point);
                  if(trade.PositionModify(ticket, novoSL, tpAtual))
                     Print("Stop movido - Protecao - ", entry, " - SELL");
               }
            } else {
               if (pontosSL > pontosMove) {
                  novoSL = slAtual - (pontosProtecao * point);
                  if(trade.PositionModify(ticket, novoSL, tpAtual))
                     Print("Stop movido - ", novoSL, " - SELL");
               }
            }
         }
      } else if(profit < 0) {
         if(type == POSITION_TYPE_BUY ) {
           BUY_COUNT--;
         } else {
           SELL_COUNT--;
         }
      }
      
   }
}

bool hasPositionOpenWithMagicNumber(int position, ulong magicNumberRobot){
   if(hasPositionOpen(position)){
      ulong ticket = PositionGetTicket(position);
      PositionSelectByTicket(ticket);
      ulong magicNumber = PositionGetInteger(POSITION_MAGIC);
      if(magicNumber == magicNumberRobot){
         return true;
      }
   }
   
   return false;
   
}

bool hasPositionOpen(int position){
    string symbol = PositionGetSymbol(position);
    if(PositionSelect(symbol) == true) {
      return true;       
    }
    
    return false;
}
void closeBuyOrSell(int position, ulong magicNumber){
   if(hasPositionOpenWithMagicNumber(position, magicNumber)){
      ulong ticket = PositionGetTicket(position);
      trade.PositionClose(ticket);
   }
   
  // ulong ticket = OrderGetTicket(position);
  // trade.OrderDelete(ticket);
}

void closeAll(){
   int total = PositionsTotal() - 1;
   for(int position = total; position >= 0; position--)  {
      closeBuyOrSell(position, MAGIC_NUMBER);
   }
}
//+------------------------------------------------------------------+
bool IsNewDay()
{
   static datetime last_day = 0;
   datetime current_day = iTime(_Symbol, PERIOD_D1, 0);

   if(last_day != current_day)
   {
      last_day = current_day;
      return true;
   }
   return false;
}
//+------------------------------------------------------------------+
bool IsNewBar(TimeframeConfig &config)
{
   datetime currentBarTime = iTime(_Symbol, config.tf, 0);

   if(currentBarTime == 0)
      return false;

   if(config.lastBarTime == 0)
   {
      config.lastBarTime = currentBarTime;
      return false;
   }

   if(currentBarTime != config.lastBarTime)
   {
      config.lastBarTime = currentBarTime;
      return true;
   }

   return false;
}

bool CheckDailyMaxLoss(double percentLossPerDay, string log_prefix = "") {
    if(PERCENT_LOSS_PER_DAY <= 0) {
       return true;
    }
    static double daily_loss = 0.0;
    static datetime current_day = 0;
    double max_loss_dollars = BALANCE * (PERCENT_LOSS_PER_DAY / 100);
    
    datetime today = iTime(_Symbol, PERIOD_D1, 0);
    
    // Novo dia = reset perda
    if(current_day != today) {
        current_day = today;
        daily_loss = 0.0;
        if(log_prefix != "") Print(log_prefix, "🟢 NOVO DIA - Perda resetada");
        return true;
    }
    
    // Calcula perda do dia (todas posições)
    double today_loss = 0.0;
    HistorySelect(today, TimeCurrent());
    
    for(int i = 0; i < HistoryDealsTotal(); i++) {
        ulong ticket = HistoryDealGetTicket(i);
        if(HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT) {
            double profit =  HistoryDealGetDouble(ticket, DEAL_PROFIT);
            COUNTER_PROFIT += profit > 0 ? 1 : 0;
            COUNTER_LOSS += profit < 0 ? 1 : 0;
            
            today_loss += profit;
            today_loss += HistoryDealGetDouble(ticket, DEAL_SWAP);
            today_loss += HistoryDealGetDouble(ticket, DEAL_COMMISSION);
        }
    }
    
    daily_loss = today_loss;
    
    if(daily_loss <= -max_loss_dollars) {
        if(log_prefix != "") {
            Print(log_prefix, "❌ MAX LOSS DIÁRIO ATINGIDO! $", 
                  DoubleToString(MathAbs(daily_loss), 2), "/", max_loss_dollars);
        }
        return false;  // Pare de operar
    }
    
    return true;  // Pode operar
}

bool IsMarketOpenNow(int minutos = 0){
   datetime agora = TimeLocal();

   // Converte para estrutura
   MqlDateTime tempo;
   TimeToStruct(agora, tempo);

   int hora = tempo.hour;
   int minuto = tempo.min;
   if(hora >= 17 && minuto  >= 30 && hora <= 19){   
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
bool HasPositionForMagic(ulong magicNumber)
{
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;

      if(!PositionSelectByTicket(ticket))
         continue;

      string symbol = PositionGetString(POSITION_SYMBOL);
      ulong magic = (ulong)PositionGetInteger(POSITION_MAGIC);

      if(symbol == _Symbol && magic == magicNumber)
         return true;
   }

   return false;
}
//+------------------------------------------------------------------+
bool IsBullish(const MqlRates &candle)
{
   return candle.close > candle.open;
}
//+------------------------------------------------------------------+
bool IsBearish(const MqlRates &candle)
{
   return candle.close < candle.open;
}
//+------------------------------------------------------------------+
bool GetLastClosedCandles(ENUM_TIMEFRAMES tf, MqlRates &rates[])
{
   ArraySetAsSeries(rates, true);

   int copied = CopyRates(_Symbol, tf, 0, QTD_CANDLES * 2, rates);
   if(copied < QTD_CANDLES)
   {
      Print("Erro ao copiar candles de ", TimeframeToLabel(tf), ". Copiados: ", copied, " Erro: ", GetLastError());
      return false;
   }

   return true;
}

bool GetAdx(ENUM_TIMEFRAMES tf) { 
   double adx[1];
   double adxPlus[1];
   double adxMinus[1];
   // Handle ADX
   int handleADX = iADX(_Symbol, tf, 14);
   if(handleADX == INVALID_HANDLE)
      return false;

   if(CopyBuffer(handleADX, 0, 0, 1, adx) <= 0  ||  CopyBuffer(handleADX, 2, 0, 1, adxMinus) <= 0 || CopyBuffer(handleADX, 1, 0, 1, adxPlus) <= 0)
      return false;
      
   VALUE_ADX[0] = adx[0]; 
   VALUE_ADX[1] = adxPlus[0];
   VALUE_ADX[2] = adxMinus[0];  
   return true;
}

bool GetCci(ENUM_TIMEFRAMES tf) { 
   // Handle ADX
   int handleCCI = iCCI(_Symbol, tf, 14, PRICE_TYPICAL);
   if(handleCCI == INVALID_HANDLE)
      return false;

   if(CopyBuffer(handleCCI, 0, 0, 3, VALUE_CCI) <= 0)
      return false;
       
   return true;
}

bool GetMovingAverage(ENUM_TIMEFRAMES tf, int period, double &buffer[]) {   
   // Handle MA
   int handleMA = iMA(_Symbol, tf, period, 0, MODE_EMA, PRICE_CLOSE);
   if(handleMA == INVALID_HANDLE)
      return false;

   // Pegando últimos 3 valores da média
   if(CopyBuffer(handleMA, 0, 0, 3, buffer) <= 0)
      return false;

   return true;
}

void VerifyEngolfo(TimeframeConfig &config) {
   bool c1Bull = IsBullish(candles[0]);
   bool c2Bull = IsBullish(candles[1]);
   bool c3Bull = IsBullish(candles[2]);
   bool c4Bull = IsBullish(candles[3]);

   bool c1Bear = IsBearish(candles[0]);
   bool c2Bear = IsBearish(candles[1]);
   bool c3Bear = IsBearish(candles[2]);
   bool c4Bear = IsBearish(candles[3]);
   
   int initialTendency = 0, finalTendency = 0;
   if(config.candleCandidateCounter <= 0) {
      initialTendency = getCandleTendecy(1, QTD_CANDLES, 3, true, 0);  
      if(initialTendency == -1 && c2Bear && c1Bull && candles[0].close > candles[1].open){
         drawVerticalLine(candles[0].time, "Object_line_candleCandidato_" + EnumToString(config.tf) + "_BUY_ENGOLFO" + TimeToString(candles[0].time), clrWhite);
         config.candleCandidate = candles[0];
         config.lastCandleCandidate = candles[1];  
         config.candleCandidateTendency = BUY;
         config.candleCandidateCounter = MIN_COUNT_CANDIDATE_CANDLE;
      } else  if(initialTendency == 1 && c2Bull && c1Bear && candles[0].close < candles[1].open){
         drawVerticalLine(candles[0].time, "Object_line_candleCandidato_" + EnumToString(config.tf) + "_SELL_ENGOLFO" + TimeToString(candles[0].time), clrRed);
         config.candleCandidate = candles[0];
         config.lastCandleCandidate = candles[1]; 
         config.candleCandidateTendency = SELL;
         config.candleCandidateCounter = MIN_COUNT_CANDIDATE_CANDLE;
      }
   } else {
    if (config.candleCandidateCounter <= 4) {
         double proporcaoTempo = 1.2;
         MaximosMinimos maxMin = getMinOrMax(1, MIN_COUNT_CANDIDATE_CANDLE);
         double newVolume = NormalizeVolume(ENABLE_TIMEFRAME_MULTIPLIER ? VOLUME * config.multiplier : VOLUME);
         bool diff = DISABLED_ADX_SIZE_VALIDATIONS ||  MathAbs(VALUE_ADX[1] - VALUE_ADX[2])  > 10;
         
         if(!diff) {
            return;
         }
         
         if(IsBullish(config.candleCandidate) && candles[0].close < maxMin.low 
            && VALUE_MOVING_AVERAGE[0] > candles[0].close && VALUE_MOVING_AVERAGE[1] > candles[0].close && VALUE_MOVING_AVERAGE[2] > candles[0].close 
            && VALUE_ADX[1] < VALUE_ADX[2]){
            int remainingSeconds = calcularCandleTime();
            if(remainingSeconds > config.tfSeconds / proporcaoTempo) {
               return ;
            }
            double ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
            double sl = calcPoints(maxMin.high, candles[0].close);
            double tp = sl * PROPORTION_TAKE_STOP;
      
            if(candles[0].spread > sl)
               return;
      
            trade.SetExpertMagicNumber(config.magicNumber);
            bool ok = toSell(ask, newVolume, sl, tp, "SELL_ENGOLFO_" + config.label);
            if(ok) {
               config.signalTendencia = SELL;
               config.candleCandidateCounter = 0;
               config.candleCandidateTendency = NONE;
               countOrders++;
               Print("Sell executado com sucesso em ", config.label);
            }
            
       } else if(IsBullish(config.candleCandidate) && IsBullish(candles[0]) && candles[0].close > config.candleCandidate.close && candles[0].close < config.lastCandleCandidate.close
            && VALUE_MOVING_AVERAGE[0] < candles[0].close && VALUE_MOVING_AVERAGE[1] < candles[0].close && VALUE_MOVING_AVERAGE[2] < candles[0].close 
            && VALUE_ADX[1] < VALUE_ADX[2]){
            int remainingSeconds = calcularCandleTime();
            if(remainingSeconds > config.tfSeconds / proporcaoTempo) {
               return ;
            }
            double bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);
            double sl = calcPoints(maxMin.low, candles[0].close);
            double tp = sl * PROPORTION_TAKE_STOP;
      
            if(candles[0].spread > sl)
               return;
      
            trade.SetExpertMagicNumber(config.magicNumber);
            bool ok = toBuy(bid, newVolume, sl, tp, "BUY_ENGOLFO_REVERSION_" + config.label);
            if(ok) {
               config.signalTendencia = BUY;
               config.candleCandidateCounter = 0;
               config.candleCandidateTendency = NONE;
               countOrders++;
               Print("BUY executado com sucesso em ", config.label);
            }
            
       } else if(IsBearish(config.candleCandidate) && IsBearish(candles[0]) && candles[0].close < config.candleCandidate.close && candles[0].close > config.lastCandleCandidate.close
            && VALUE_MOVING_AVERAGE[0] > candles[0].close && VALUE_MOVING_AVERAGE[1] > candles[0].close && VALUE_MOVING_AVERAGE[2] > candles[0].close 
            && VALUE_ADX[1] > VALUE_ADX[2]){
            int remainingSeconds = calcularCandleTime();
            if(remainingSeconds > config.tfSeconds / proporcaoTempo) {
               return ;
            }
            double ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
            double sl = calcPoints(maxMin.high, candles[0].close);
            double tp = sl * PROPORTION_TAKE_STOP;
      
            if(candles[0].spread > sl)
               return;
      
            trade.SetExpertMagicNumber(config.magicNumber);
            bool ok = toSell(ask, newVolume, sl, tp, "SELL_ENGOLFO_" + config.label);
            if(ok) {
               config.signalTendencia = SELL;
               config.candleCandidateCounter = 0;
               config.candleCandidateTendency = NONE;
               countOrders++;
               Print("Sell executado com sucesso em ", config.label);
            }
            
       } else if(IsBearish(config.candleCandidate) && candles[0].close > maxMin.high
            && VALUE_MOVING_AVERAGE[0] < candles[0].close && VALUE_MOVING_AVERAGE[1] < candles[0].close && VALUE_MOVING_AVERAGE[2] < candles[0].close 
            && VALUE_ADX[1] > VALUE_ADX[2]){
            int remainingSeconds = calcularCandleTime();
            if(remainingSeconds > config.tfSeconds / proporcaoTempo) {
               return ;
            }
            double bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);
            double sl = calcPoints(maxMin.low, candles[0].close);
            double tp = sl * PROPORTION_TAKE_STOP;
      
            if(candles[0].spread > sl)
               return;
      
            trade.SetExpertMagicNumber(config.magicNumber);
            bool ok = toBuy(bid, newVolume, sl, tp, "BUY_ENGOLFO_" + config.label);
            if(ok) {
               config.signalTendencia = BUY;
               config.candleCandidateCounter = 0;
               config.candleCandidateTendency = NONE;
               countOrders++;
               Print("BUY executado com sucesso em ", config.label);
            }
         }
      }
   }
   
}

//+------------------------------------------------------------------+

void VerifyTendency(TimeframeConfig &config) {
   int index = 1;
   int min = MathRound((double)QTD_CANDLES / 2.0);
   int initialTendency = getCandleTendecy(index, QTD_CANDLES, min, false, PERCENTUAL_ACCEPTABLE_CANDLE_BODY);
   datetime actualTime = candles[index].time;
   double precoAtual = candles[0].close;
   double minAnterior = candles[1].open;
   double newVolume = NormalizeVolume(ENABLE_TIMEFRAME_MULTIPLIER ? VOLUME * config.multiplier : VOLUME);
 //  bool isMercadoNaoLateralizado = DISABLED_LATERAL_MARKET_VALIDATIONS || !MercadoLateral();
   bool diff = DISABLED_ADX_SIZE_VALIDATIONS ||  MathAbs(VALUE_ADX[1] - VALUE_ADX[2])  > 10;
   datetime expiration = TimeCurrent() + config.tfSeconds * 3;
   double profit = AccountInfoDouble(ACCOUNT_PROFIT);
   
   if(initialTendency == -1  && diff){
      drawVerticalLine(actualTime, "Object_line_candleCandidato_" + EnumToString(config.tf) + "_SELL_CANDIDATO" + TimeToString(expiration), clrRed);
      if( VALUE_MOVING_AVERAGE[0] < candles[4].close && VALUE_MOVING_AVERAGE[0] < candles[3].close && VALUE_MOVING_AVERAGE[0] < candles[2].close 
         && VALUE_MOVING_AVERAGE[0] > precoAtual && VALUE_MOVING_AVERAGE[1] > precoAtual && VALUE_MOVING_AVERAGE[2] > precoAtual
         && VALUE_ADX[1] < VALUE_ADX[2]) {
         Print("SELL TENDENCY SUPER TRUNFO -  ", config.label);
         config.actualTendency = SELL;
         MaximosMinimos maxMin = getMinOrMax(1, QTD_CANDLES);
         double sl = maxMin.high;
         double diff = calcPoints(precoAtual, sl);
         if (diff < 300) {
            maxMin = getMinOrMax(1, QTD_CANDLES + 2);
            sl = maxMin.low;
            diff = calcPoints(precoAtual, sl);
         }
         double tp = calcPrice(precoAtual, -diff * 2);
         
         trade.SetExpertMagicNumber(config.magicNumber);
         bool ok = trade.Sell(newVolume, _Symbol, precoAtual, sl, tp, "SELL_TENDENCY_TRUNFO_" + config.label);
         if(ok){
            config.waitNewCandle = true;
            config.maxRobots = NUMBER_MAX_ROBOT_BY_TIMEFRAME;
            drawVerticalLine(actualTime, "Object_line_candleCandidato_" + EnumToString(config.tf) + "_SELL_TRUNFO" + TimeToString(expiration), clrRed);
            Print("BUY TENDENCY executado com sucesso em ", config.label);
         }
         
      }
      
      //IsBullish(candles[1]) && funciona
      if (VALUE_MOVING_AVERAGE[0] > precoAtual && VALUE_MOVING_AVERAGE[1] > precoAtual && VALUE_MOVING_AVERAGE[2] > precoAtual 
         && VALUE_ADX[2] > VALUE_ADX[1] ) {
         Print("Verificação de tendencia - ", config.label, " - BUY", " - Volume - ", newVolume);
         config.actualTendency = SELL;
         MaximosMinimos maxMin = getMinOrMax(1, QTD_CANDLES);
         double sl = maxMin.high;
         double diff = calcPoints(precoAtual, sl);
         if (diff < 300) {
            maxMin = getMinOrMax(1, QTD_CANDLES + 2);
            sl = maxMin.low;
            diff = calcPoints(precoAtual, sl);
         }
         double tp = calcPrice(precoAtual, -diff);
         
         double pointsDiffAverage = calcPoints(VALUE_MOVING_AVERAGE[0], precoAtual); 
         double pointsDiffSl = calcPoints(precoAtual, sl); 
         if(!DISABLED_SECONDARY_VALIDATIONS && pointsDiffAverage < pointsDiffSl) {
            Print("Primeira barreira");
            return;
         }
         
         trade.SetExpertMagicNumber(config.magicNumber);
         if (!DISABLED_SECONDARY_VALIDATIONS && IsTrendSaturated(SELL, precoAtual, maxMin)) {
            Print("Segunda barreira");
            //double newPrice = calcPrice(precoAtual, diff * 0.3);
          //  trade.SellLimit(newVolume, newPrice, _Symbol, sl, tp, ORDER_TIME_SPECIFIED, expiration, "SELL_TENDENCY_SATURED_" + config.label);
            return;
         }  

         bool ok = trade.Sell(newVolume, _Symbol, precoAtual, sl, tp, "SELL_TENDENCY_" + config.label);
         if(ok){
            config.waitNewCandle = true;
            config.maxRobots = NUMBER_MAX_ROBOT_BY_TIMEFRAME;
            drawVerticalLine(actualTime, "Object_line_candleCandidato_" + EnumToString(config.tf) + "_SELL" + TimeToString(expiration), clrBlueViolet);
            Print("SELL TENDENCY executado com sucesso em ", config.label);
         }
      }
   } else  if(initialTendency == 1 && diff ){
      drawVerticalLine(actualTime, "Object_line_candleCandidato_" + EnumToString(config.tf) + "_BUY_CANDIDATO" + TimeToString(expiration), clrWhite);
      if( VALUE_MOVING_AVERAGE[0] > candles[4].close && VALUE_MOVING_AVERAGE[0] > candles[3].close && VALUE_MOVING_AVERAGE[0] > candles[2].close 
         && VALUE_MOVING_AVERAGE[0] < precoAtual && VALUE_MOVING_AVERAGE[1] < precoAtual && VALUE_MOVING_AVERAGE[2] < precoAtual
         && VALUE_ADX[1] > VALUE_ADX[2]) {
         Print("BUY TENDENCY SUPER TRUNFO -  ", config.label);
         config.actualTendency = BUY;
         MaximosMinimos maxMin = getMinOrMax(1, QTD_CANDLES);
         double sl = maxMin.low;
         double diff = calcPoints(precoAtual, sl);
         if (diff < 300) {
            maxMin = getMinOrMax(1, QTD_CANDLES + 2);
            sl = maxMin.low;
            diff = calcPoints(precoAtual, sl);
         }
         double tp = calcPrice(precoAtual, diff * 2);
         
         trade.SetExpertMagicNumber(config.magicNumber);
         bool ok = trade.Buy(newVolume, _Symbol, precoAtual, sl, tp, "BUY_TENDENCY_TRUNFO" + config.label);
         if(ok){
            config.waitNewCandle = true;
            config.maxRobots = NUMBER_MAX_ROBOT_BY_TIMEFRAME;
            drawVerticalLine(actualTime, "Object_line_candleCandidato_" + EnumToString(config.tf) + "_BUY_TRUNFO" + TimeToString(expiration), clrGreen);
            Print("BUY TENDENCY executado com sucesso em ", config.label);
         }
         
      }
      
      //IsBearish(candles[1]) && funciona
      if ( VALUE_MOVING_AVERAGE[0] < precoAtual && VALUE_MOVING_AVERAGE[1] < precoAtual && VALUE_MOVING_AVERAGE[2] < precoAtual 
         && VALUE_ADX[1] > VALUE_ADX[2]  ) {
         Print("Verificação de tendencia - ", config.label, " - SELL", " - Volume - ", newVolume);
         config.actualTendency = BUY;
         MaximosMinimos maxMin = getMinOrMax(1, QTD_CANDLES);
         double sl = maxMin.low;
         double diff = calcPoints(precoAtual, sl);
         if (diff < 300) {
            maxMin = getMinOrMax(1, QTD_CANDLES + 2);
            sl = maxMin.low;
            diff = calcPoints(precoAtual, sl);
         }
         
         double tp = calcPrice(precoAtual, diff);
         double pointsDiffAverage = calcPoints(VALUE_MOVING_AVERAGE[0], precoAtual); 
         double pointsDiffSl = calcPoints(precoAtual, sl); 
         if(!DISABLED_SECONDARY_VALIDATIONS && pointsDiffAverage < pointsDiffSl) {
            Print("Primeira barreira");
            return;
         //   return;
         }
         
         trade.SetExpertMagicNumber(config.magicNumber);
         if (!DISABLED_SECONDARY_VALIDATIONS && IsTrendSaturated(BUY, precoAtual, maxMin)) {
            Print("Segunda barreira");
          //  trade.Buy(newVolume, _Symbol, precoAtual, sl, tp, "BUY_TENDENCY_SATURED_" + config.label);
        //      double newPrice = calcPrice(precoAtual, -diff * 0.3);
        //      trade.BuyLimit(newVolume, newPrice, _Symbol, sl, tp, ORDER_TIME_SPECIFIED, expiration, "BUY_TENDENCY_SATURED_" + config.label);
            return;
         }  
         
         bool ok = trade.Buy(newVolume, _Symbol, precoAtual, sl, tp, "BUY_TENDENCY_" + config.label);
         if(ok){
            config.waitNewCandle = true;
            config.maxRobots = NUMBER_MAX_ROBOT_BY_TIMEFRAME;
            drawVerticalLine(actualTime, "Object_line_candleCandidato_" + EnumToString(config.tf) + "_BUY" + TimeToString(expiration), clrYellow);
            Print("BUY TENDENCY executado com sucesso em ", config.label);
         }
      }
   }
}

double NormalizeVolume(double volume){
   double minVol  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxVol  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double stepVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   if(stepVol <= 0.0)
      return volume;

   volume = MathMax(minVol, MathMin(maxVol, volume));
   volume = MathFloor(volume / stepVol) * stepVol;

   return NormalizeDouble(volume, 2);
}

void drawVerticalLine(datetime time, string nameLine, color indColor){
   ObjectCreate(ChartID(),nameLine,OBJ_VLINE,0,time,0);
   ObjectSetInteger(0,nameLine,OBJPROP_COLOR,indColor);
   ObjectSetInteger(0,nameLine,OBJPROP_WIDTH,1);
   ObjectMove(ChartID(),nameLine,0,time, 0);
}

void drawHorizontalLine(double price, datetime time, string nameLine, color indColor){
   ObjectCreate(ChartID(),nameLine,OBJ_HLINE,0,time,price);
   ObjectSetInteger(0,nameLine,OBJPROP_COLOR,indColor);
   ObjectSetInteger(0,nameLine,OBJPROP_WIDTH,1);
   ObjectMove(ChartID(),nameLine,0,time,price);
}
//+------------------------------------------------------------------+
double calcPoints(double val1, double val2, bool absValue = true)
{
   if(absValue)
      return MathAbs(val1 - val2) / _Point;
   else
      return (val1 - val2) / _Point;
}
BordersOperation normalizeTakeProfitAndStopLoss(double stopLoss, double takeProfit){
   BordersOperation borders;
   borders.min = 0;
   borders.max = 0; 
   
   // modificação para o indice dolar DOLAR_INDEX
   if(stopLoss != 0 || takeProfit != 0){
      if(_Digits == 3){
         borders.min = (stopLoss * 1000);
         borders.max = (takeProfit * 1000);  
      }else{
         borders.min = NormalizeDouble((stopLoss * _Point), _Digits);
         borders.max = NormalizeDouble((takeProfit * _Point), _Digits); 
      }
   }
   
   return borders;
}

bool toBuy(double price, double volume, double stopLoss, double takeProfit, string comment){
   BordersOperation borders = normalizeTakeProfitAndStopLoss(stopLoss, takeProfit);
   double stopLossNormalized = NormalizeDouble((price - borders.min), _Digits);
   double takeProfitNormalized = NormalizeDouble((price + borders.max), _Digits);
   double entry = NormalizeDouble(price,_Digits);
   return trade.Buy(volume, _Symbol, entry, stopLossNormalized, takeProfitNormalized, comment);
}

bool toSell(double price, double volume, double stopLoss, double takeProfit, string comment){
   BordersOperation borders = normalizeTakeProfitAndStopLoss(stopLoss, takeProfit);
   double stopLossNormalized = NormalizeDouble((price + borders.min), _Digits);
   double takeProfitNormalized = NormalizeDouble((price - borders.max), _Digits);  
   double entry = NormalizeDouble(price, _Digits);
   return trade.Sell(volume, _Symbol, entry, stopLossNormalized, takeProfitNormalized, comment); 
}
//+------------------------------------------------------------------+
MaximosMinimos getMinOrMax(int start, int end) {
   double high = 0;
   double low = 999999;
   double minClose = 999999;
   double minOpen = 999999;
   double maxClose = 0;
   double maxOpen = 0;
   MaximosMinimos maxMin;
   
   for(int i = start; i < end; i++) {
      if (candles[i].low < low) {
         low = candles[i].low;
      }
      if (candles[i].high > high) {
         high = candles[i].high;
      }
      if (candles[i].close < minClose) {
         minClose = candles[i].close;
      }
      if (candles[i].close > maxClose) {
         maxClose = candles[i].close;
      }
      if (candles[i].open < minOpen) {
         minOpen = candles[i].open;
      }
      if (candles[i].open > maxOpen) {
         maxOpen = candles[i].open;
      }
   }

   maxMin.low = low;
   maxMin.high = high;
   maxMin.minClose = minClose;
   maxMin.minOpen = minOpen;
   maxMin.maxClose = maxClose;
   maxMin.maxOpen = maxOpen;

   return maxMin;
   
}

double getBodyOrWick(MqlRates &candle, bool body) {
   double bodyCandle = calcPoints(candle.close, candle.open);
   if(body) {
      return bodyCandle;
   } 
   
   return MathAbs(bodyCandle - calcPoints(candle.high, candle.low));
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
int getCandleTendecy(int start, int end, int limit, bool ignoreType, double bodySize) {
   int bearishCount = 0;
   int bullishCount = 0;
   int low = 0;
   int high = 0;
   for(int i = start; i < end; i++) {
      double body = getBodyOrWick(candles[i], true);
      double wick = getBodyOrWick(candles[i], false);
      
      if(i+1 < end ) {
         if(candles[i+1].open > candles[i].close 
            && body > wick * bodySize  / 100
            && candles[i+1].high > candles[i].high 
            && (ignoreType || (IsBearish(candles[i+1]) && IsBearish(candles[i])))
            ) {
            bearishCount++;
         }

         if(candles[i+1].open < candles[i].close 
            && body > wick * bodySize / 100
            && candles[i+1].low < candles[i].low 
            && (ignoreType || (IsBullish(candles[i+1]) && IsBullish(candles[i])))
           ) {
            bullishCount++;
         }
      }
   }

   if(bearishCount > bullishCount && bearishCount >= limit){
      return -1;
   }
   else if(bullishCount > bearishCount && bullishCount >= limit) {
      return 1;
   }
   
   return 0;
}

//+------------------------------------------------------------------+
//| Detecta gap entre candles                                        |
//+------------------------------------------------------------------+
bool DetectarGap(MqlRates &actualCandle, MqlRates &lastCandle, double points) {
   double highAtual = actualCandle.high;
   double lowAtual  = actualCandle.low;

   double highPrev = lastCandle.high;
   double lowPrev  = lastCandle.low;

   // Gap de alta
   double pointsGapAlta = calcPoints(lowAtual, highPrev);
   if(lowAtual > highPrev && pointsGapAlta > points)
      return true;

   // Gap de baixa
   double pointsGapBaixa = calcPoints(lowPrev, highAtual);
   if(highAtual < lowPrev && pointsGapAlta > points)
      return true;

   return false;
}

//+------------------------------------------------------------------+
double calcPrice(double price, double points)
{
   return NormalizeDouble(price + points * _Point, _Digits);
}
//+------------------------------------------------------------------+
int calcularCandleTime() {
   datetime candleOpenTime = iTime(_Symbol, _Period, 0);
   int periodSeconds = PeriodSeconds(_Period);
   datetime candleCloseTime = candleOpenTime + periodSeconds;

   int remainingSeconds = (int)(candleCloseTime - TimeCurrent());

   if(remainingSeconds < 0)
      remainingSeconds = 0;
   
   return remainingSeconds;
}

string transformarCandleTime() {
   int remainingSeconds = calcularCandleTime();
   int minutes = remainingSeconds / 60;
   int seconds = remainingSeconds % 60;

   return StringFormat("%02d:%02d", minutes, seconds);
}

bool IsTrendSaturated(TYPE_NEGOCIATION type, double precoAtual, MaximosMinimos &mm){
   // distância do preço para EMA50
   double distanceMA = calcPoints(precoAtual, VALUE_MOVING_AVERAGE[0]);
   double range = calcPoints(mm.high, mm.low);

   // candle atual muito grande
   double body = getBodyOrWick(candles[1], true);
   
   if(distanceMA > range * 0.7)
      return true;

   if(VALUE_ADX[0] > 40)
      return true;

   if(body > range * 0.5)
      return true;

   // =========================
   // SATURAÇÃO COMPRA
   // =========================
   if(type == BUY)   {
      // perda de força da tendência
      if(VALUE_ADX[1] < VALUE_ADX[2])
         return true;
   }

   // =========================
   // SATURAÇÃO VENDA
   // =========================
   if(type == SELL)  {
      if(VALUE_ADX[2] < VALUE_ADX[1])
         return true;
   }

   return false;
}

void createButton(string nameLine, int xx, int yy, int largura, int altura, int canto, int tamanho, string fonte, string text, long corTexto, long corFundo, long corBorda, bool oculto){
   ObjectCreate(ChartID(),nameLine,OBJ_BUTTON,0,0,0);
   ObjectSetInteger(0,nameLine,OBJPROP_XDISTANCE,xx);
   ObjectSetInteger(0,nameLine,OBJPROP_YDISTANCE, yy);
   ObjectSetInteger(0,nameLine,OBJPROP_XSIZE, largura);
   ObjectSetInteger(0,nameLine,OBJPROP_YSIZE, altura);
   ObjectSetInteger(0,nameLine,OBJPROP_CORNER, canto);
   ObjectSetInteger(0,nameLine,OBJPROP_FONTSIZE, tamanho);
   ObjectSetString(0,nameLine,OBJPROP_FONT, fonte);
   ObjectSetString(0,nameLine,OBJPROP_TEXT, text);
   ObjectSetInteger(0,nameLine,OBJPROP_COLOR, corTexto);
   ObjectSetInteger(0,nameLine,OBJPROP_BGCOLOR, corFundo);
   ObjectSetInteger(0,nameLine,OBJPROP_BORDER_COLOR, corBorda);
}

bool MercadoLateral(double minIdx = 20, double limiteInclinacao = 0.0001) {
   // Inclinação da média (diferença simples)
   double inclinacao = VALUE_MOVING_AVERAGE[0] - VALUE_MOVING_AVERAGE[2];

   // Condições de lateralização
   bool maReta = MathAbs(inclinacao) < limiteInclinacao;
   bool adxFraco =  VALUE_ADX[0] < minIdx || VALUE_ADX[0] < (VALUE_ADX[1] + VALUE_ADX[2]) / 2;

   if(adxFraco) 
      return true;

   return false;
}
