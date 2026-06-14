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

enum MOVE_STOP_TYPE{
   MOVE_STOP_TRAIL = 1,
   MOVE_STOP_10    = 10,
   MOVE_STOP_20    = 20,
   MOVE_STOP_30    = 30,
   MOVE_STOP_40    = 40,
   MOVE_STOP_50    = 50,
   MOVE_STOP_60    = 60,
   MOVE_STOP_70    = 70,
   MOVE_STOP_NONE  = 0
 };
 
enum MOVING_AVERAGE_TYPE {
   MV_9   = 9,
   MV_21   = 21,
   MV_50   = 50,
   MV_80   = 80,
   MV_200   = 200,
   MV_400   = 400
};
 
enum ATR_TYPE {
   ATR_0   = 0,
   ATR_0_5 = 5,
   ATR_1   = 10,
   ATR_1_5 = 15,
   ATR_2   = 20,
   ATR_2_5 = 25,
   ATR_3   = 30,
   ATR_3_5 = 35,
   ATR_4   = 40,
   ATR_4_5 = 45,
   ATR_5   = 50
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
   int maxRobotsTendency;
   int maxRobotsShortTendency;
   int maxRobotsEngolfo;
   int maxRobotsHighRisk;
   double multiplier;
   datetime lastBarTime;
   bool waitNewCandle;
   bool waitNewCandleHighRisk;
   bool enableTendency;
   bool enableInversion;
   ulong magicNumber;
   double atr[15];
   double movingAverage[15];
   double adx[15];
   double cci[15];
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


input double VOLUME = 0.04;
input int QTD_CANDLES = 5;
input int MIN_CANDLES_IN_TREND = 3;
 double ADX_MINIMUN_VALUE = 10;
input double LOSS_PER_DAY = 500;
input ATR_TYPE ATR_MINIMUM = ATR_3_5;
input MOVING_AVERAGE_TYPE MOVING_AVERAGE = MV_21;
input MOVE_STOP_TYPE MOVE_STOP = MOVE_STOP_30;
input double MOVE_STOP_PROTECTION_PERCENTUAL = 50;
 double ACCEPTABLE_CANDLE_BODY_PERCENTUAL = 70;
input double PROPORTION_TAKE_STOP = 1;
 input bool ENABLE_SHORT_TENDENCY = true;
 input bool ENABLE_TENDENCY = true;
 input bool ENABLE_ENGOLFO = true;
 input bool ENABLE_MARTINGALLE = true;
 input bool ENABLE_MULTI_ROBOTS_IN_PROFIT = true;
input bool ENABLE_TIMEFRAME_MULTIPLIER = true;
input bool ENABLE_CLOSE_IN_LOSS = false;
input bool ENABLE_SATURDAY = false;
input bool ENABLE_MONDAY = false;
input bool IGNORE_MAGIC_NUMBER = false;
input int NUMBER_MAX_ROBOT = 5;
input bool IS_TEST = false;
 bool DISABLED_NEGOTIATIONS = false;
 bool DISABLED_SECONDARY_VALIDATIONS = true;
 bool DISABLED_LATERAL_MARKET_VALIDATIONS = true;
input bool ENABLE_SWING_TRADE = false;
 bool ENABLE_MOVE_TAKE = false;
double CCI_MAX = 180;

 int NUMBER_MAX_ROBOT_BY_TIMEFRAME = 3;
 
double BALANCE = 0;
double COUNTER_LOSS = 0, COUNTER_PROFIT = 0;
ulong MAGIC_NUMBER = 97889902933;

TimeframeConfig configs[];
string labelName = "CandleTimer";
MqlRates candles[];
MqlTick tick;        
int countOrders = 0;
bool countCycles = false, waitNewCandleMultRobot = false, waitNewCandleMartingalle = false;
int MIN_COUNT_CANDIDATE_CANDLE = 5, BUY_COUNT = 0, SELL_COUNT = 0;
ENUM_TIMEFRAMES tfs[] = { PERIOD_M10, PERIOD_M15, PERIOD_M20, PERIOD_M30, PERIOD_H1, PERIOD_H2, PERIOD_H3, PERIOD_H4};
//---ENUM_TIMEFRAMES tfs[] = { PERIOD_M10 };
bool MAX_LOSS_ATINGIDO = false;

//
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
         " Total de posições ativas: ", (PositionsTotal()), 
         " Saldo: ", DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE) + profit, 2),
         " Lucro Atual: ", DoubleToString(profit, 2),
         " Tempo de Candle: ", transformarCandleTime(),
         " Tendencias: ", getTendenciaMacro()
         );
}

string getTendenciaMacro(){
   string tendency = "";
   for(int i = 0; i < ArraySize(configs); i++) {
      if(configs[i].actualTendency != NONE) {
         tendency +=  configs[i].label + ": " + EnumToString(configs[i].actualTendency) + ", ";
      }
   }
   
   return tendency;
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

int TimeframeToSeconds(ENUM_TIMEFRAMES tf) {
   return PeriodSeconds(tf);
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


void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam){
//---
   // Fechar negociacões
   if(id == CHARTEVENT_OBJECT_CLICK){
      if(sparam == "btnCloseBuy"){
         closeAllPositionsByType(POSITION_TYPE_BUY, 0);
      }
      if(sparam == "btnCloseSell"){
         closeAllPositionsByType(POSITION_TYPE_SELL, 0);
      }
      
      if(sparam == "btnCloseAll"){
         closeAll();
      }
      if(sparam == "btnProtectAll"){
         protectPositions(15);
      }
    
   }
}

//+------------------------------------------------------------------+
int OnInit()
{
   
   generateButtons();
   ArrayResize(configs, ArraySize(tfs));

   for(int i = 0; i < ArraySize(tfs); i++) {
      configs[i].tf = tfs[i];
      configs[i].lastBarTime = 0;
      configs[i].maxRobots = NUMBER_MAX_ROBOT;
      configs[i].maxRobotsEngolfo = NUMBER_MAX_ROBOT;
      configs[i].maxRobotsTendency = NUMBER_MAX_ROBOT;
      configs[i].maxRobotsShortTendency = NUMBER_MAX_ROBOT;
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
      MAX_LOSS_ATINGIDO = false;
   }
   
   if(HasNewCandle(PERIOD_M5)) {
      waitNewCandleMultRobot = false;
      waitNewCandleMartingalle = false;
   }
   
   if(HasNewCandle(PERIOD_M1)) {  
      if (MOVE_STOP != MOVE_STOP_NONE) {
         if (MOVE_STOP != MOVE_STOP_TRAIL) {
             MoveStopPorPontos();
         }
      }
   }
   
   if(!IS_TEST) {
      showComments();
      if(!CheckDailyMaxLoss(LOSS_PER_DAY, "USD ")) {
           printf("Perda maxima atingida.");
           closeAll();
           return;  
      }
   
      if(HasNewCandle(PERIOD_M10)) {
         if(!ENABLE_SWING_TRADE){
            if(!IsMarketOpenNow(30)){
               printf("%s Mercado fechado!", _Symbol);
               closeAll();
               return; 
            }
         }
         
         COUNTER_PROFIT = 0;
         COUNTER_LOSS = 0;
      }
   }
  
   for(int i = 0; i < ArraySize(configs); i++)  {
      if(!GetLastClosedCandles(configs[i].tf, candles)) {
         printf("Candles Nao Recuperados - " + EnumToString(configs[i].tf));
         return;
      } 
      
      if (!GetMovingAverage(configs[i], MOVING_AVERAGE, configs[i].movingAverage)) {
         printf("Media " + IntegerToString(MOVING_AVERAGE) + " Nao Recuperada - " + EnumToString(configs[i].tf));
         return;
      }   
      
      if (!GetAdx(configs[i])) {
         printf("ADX Nao Recuperado - " + EnumToString(configs[i].tf));
         return;
      }   
      
      if (!GetCci(configs[i])) {
         printf("CCI Nao Recuperado - " + EnumToString(configs[i].tf));
         return;
      }   
      
      if (!GetAtr(configs[i])) {
         printf("Atr Nao Recuperado - " + EnumToString(configs[i].tf));
         return;
      }
     
    
      int totalPositions = PositionsTotal();
      if(totalPositions == 0) {
         configs[i].waitNewCandle = false;
         configs[i].waitNewCandleHighRisk = false;
         configs[i].maxRobotsEngolfo = NUMBER_MAX_ROBOT;
         configs[i].maxRobotsTendency = NUMBER_MAX_ROBOT;
         configs[i].maxRobotsShortTendency = NUMBER_MAX_ROBOT;
      }
      
      if (configs[i].maxRobotsEngolfo < 0 && totalPositions < NUMBER_MAX_ROBOT) {
         configs[i].maxRobotsEngolfo = NUMBER_MAX_ROBOT;
         printf("Resetando robos de engolfo!");
      }
      
      if (configs[i].maxRobotsTendency < 0 && totalPositions < NUMBER_MAX_ROBOT) {
         configs[i].maxRobotsTendency = NUMBER_MAX_ROBOT;
         printf("Resetando robos de tendencia longa!");
      }
      
      if (configs[i].maxRobotsShortTendency < 0 && totalPositions < NUMBER_MAX_ROBOT) {
         configs[i].maxRobotsShortTendency = NUMBER_MAX_ROBOT;
         printf("Resetando robos de tendencia curta!");
      }
      
      if (MOVE_STOP == MOVE_STOP_TRAIL) {
         MoveStopByATR(configs[i]);
      } 

      if (ENABLE_SHORT_TENDENCY) {
         VerifyShortTendency(configs[i]);
      }
         
      if(IsNewBar(configs[i])) {
         configs[i].waitNewCandle = false;
         configs[i].waitNewCandleHighRisk = false;
         
         if(!IS_TEST)
            //DeleteHorizontalLinesByPrefix(configs[i].tf);

         if (ENABLE_TENDENCY) {
            //VerifyOther(configs[i]);
            VerifyTendency(configs[i]);
         }
      
         if(ENABLE_ENGOLFO) {
           VerifyEngolfo(configs[i]);
         }  /**/
      }  
   }
} 

bool IsMaxRobots() {
   if (NUMBER_MAX_ROBOT == 0) {
      return false;
   }

   int count = 0;
   if (ENABLE_ENGOLFO) {
      count++;
   }
   if (ENABLE_TENDENCY) {
      count++;
   }
   if (ENABLE_SHORT_TENDENCY) {
      count++;
   }
   
   return PositionsTotal() > NUMBER_MAX_ROBOT * count;
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

//+------------------------------------------------------------------+
//| Move o Stop Loss por pontos                                      |
//| pontos = distância em pontos do preço atual                      |
//+------------------------------------------------------------------+
void MoveStopPorPontos()
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   int totalPeriodos = 0, totalPeriodosMartingalle = 0, countLoss = 0;
   int total = PositionsTotal();
   double profitLoss = 0, profitWins = 0;
   bool positionsInLoss[];
   
   ArrayResize(positionsInLoss, total);
   for(int i = 0; i < total; i++) {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;

      if(!PositionSelectByTicket(ticket))
         continue;

      string symbol = PositionGetString(POSITION_SYMBOL);
      if(symbol != _Symbol)
         continue;

      ulong magic = (ulong)PositionGetInteger(POSITION_MAGIC);
      if(!IGNORE_MAGIC_NUMBER && magic != MAGIC_NUMBER)
         continue;

      long type        = PositionGetInteger(POSITION_TYPE);
      double slAtual   = PositionGetDouble(POSITION_SL);
      double tpAtual   = PositionGetDouble(POSITION_TP);
      double entry     = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
      double profit = PositionGetDouble(POSITION_PROFIT);
      double volume = PositionGetDouble(POSITION_VOLUME);
      double novoSL, novoTP;

      BUY_COUNT = 0;
      SELL_COUNT = 0;
      double percentualMoveStop = MOVE_STOP_20;
      double pontosTP = calcPoints(entry, tpAtual);
      double pontosMove = pontosTP  * percentualMoveStop / 100;
      double pontosSL = calcPoints(slAtual, currentPrice);
      double pontosEntrada = calcPoints(entry, currentPrice);
      double pontosProtecao = pontosMove * percentualMoveStop / 100;
      if (profit > 0) {
         string comentario =   PositionGetString(POSITION_COMMENT);
         ENUM_TIMEFRAMES tf = getTfByComment(comentario);
   
         if(tf != PERIOD_MN1)  {
            totalPeriodos++;
         }
         
         double percentProtenction = MOVE_STOP_PROTECTION_PERCENTUAL / 100;
         if(type == POSITION_TYPE_BUY ) {
            BUY_COUNT++;
            if (entry > slAtual || slAtual == 0) {
               tpAtual = tpAtual == 0 ? calcPrice(currentPrice, 1000) : tpAtual;
               pontosMove = 1000  * percentualMoveStop / 100;
               if (pontosEntrada > pontosMove * percentProtenction) {
                  novoSL = NormalizeDouble(entry + (pontosProtecao * percentProtenction * point),  _Digits);
                  if(trade.PositionModify(ticket, novoSL, tpAtual))
                     Print("Stop movido - Protecao - ", entry, " - BUY");
               } 
            } else {
              // MoveTakeProfitIfNearTarget(ticket);
               if (pontosSL > pontosMove) {
                  novoSL = NormalizeDouble(slAtual + (pontosProtecao * point),  _Digits);
                  novoTP = ENABLE_MOVE_TAKE ? NormalizeDouble(tpAtual + (pontosProtecao * point),  _Digits) : tpAtual;
                  if(trade.PositionModify(ticket, novoSL, novoTP))
                     Print("Stop movido - ", novoSL, " - BUY");
               }
            }
         
            if(ENABLE_MULTI_ROBOTS_IN_PROFIT && !IsMaxRobots() && totalPeriodos > 2 && !waitNewCandleMultRobot) {
               double diff = calcPoints(currentPrice, tpAtual);
               double newValues = calcPrice(currentPrice, -diff);
               bool ok = trade.Buy(VOLUME, _Symbol, currentPrice, newValues, tpAtual, "BUY_MULT_ROBOTS");
               if(ok) {
                  waitNewCandleMultRobot = true;
               }
            }
         }
   
         if(type == POSITION_TYPE_SELL) {
            SELL_COUNT++;
            if (entry < slAtual || slAtual == 0) {
               tpAtual = tpAtual == 0 ? calcPrice(currentPrice, -1000) : tpAtual;
               pontosMove = 1000  * percentualMoveStop / 100;
               if (pontosEntrada > pontosMove * percentProtenction) {
                  novoSL = NormalizeDouble(entry - (pontosProtecao  *  percentProtenction * point),  _Digits);
                  if(trade.PositionModify(ticket, novoSL, tpAtual))
                     Print("Stop movido - Protecao - ", entry, " - SELL");
               } 
            } else {
              // MoveTakeProfitIfNearTarget(ticket);
               if (pontosSL > pontosMove) {
                  novoSL = NormalizeDouble(slAtual - (pontosProtecao * point),  _Digits);
                  novoTP = ENABLE_MOVE_TAKE ? NormalizeDouble(tpAtual - (pontosProtecao * point),  _Digits) : tpAtual;
                  if(trade.PositionModify(ticket, novoSL, novoTP))
                     Print("Stop movido - ", novoSL, " - SELL");
               }
            }
         
            if(ENABLE_MULTI_ROBOTS_IN_PROFIT && !IsMaxRobots() && totalPeriodos > 2 && !waitNewCandleMultRobot) {
               double diff = calcPoints(currentPrice, tpAtual);
               double newValues = calcPrice(currentPrice, diff);
               
               bool ok = trade.Sell(VOLUME, _Symbol, currentPrice, newValues, tpAtual, "SELL_MULT_ROBOTS");
               if(ok) {
                  waitNewCandleMultRobot = true;
               }
            }
         }
        positionsInLoss[i] = false;
        profitWins += MathAbs(profit);
      } else if(profit < 0) {
        positionsInLoss[i] = true;
        profitLoss += MathAbs(profit);
      }
      
   }
     
    if (ENABLE_CLOSE_IN_LOSS && profitLoss >= LOSS_PER_DAY && (profitWins - profitLoss) < 0) {
        for(int i = 0; i < total; i++) {
            if (positionsInLoss[i]) {
               closeBuyOrSell(i, MAGIC_NUMBER);
            } else {
               moveStopToZeroPlusPoint(i, candles[0].spread);
            }
        }
    }
}

bool MoveTakeProfitIfNearTarget(ulong ticket)
{
   if(!PositionSelectByTicket(ticket))
      return false;

   ENUM_POSITION_TYPE type =
      (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentTP = PositionGetDouble(POSITION_TP);
   double currentSL = PositionGetDouble(POSITION_SL);

   if(currentTP <= 0)
      return false;

   double currentPrice =
      (type == POSITION_TYPE_BUY)
      ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
      : SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   double totalDistance;
   double remainingDistance;

   if(type == POSITION_TYPE_BUY)
   {
      totalDistance = currentTP - openPrice;
      remainingDistance = currentTP - currentPrice;
   }
   else
   {
      totalDistance = openPrice - currentTP;
      remainingDistance = currentPrice - currentTP;
   }

   if(totalDistance <= 0)
      return false;

   // Falta menos de 10% para atingir o TP?
   double percent =  MOVE_STOP/ 100;
   if(remainingDistance <= totalDistance * percent * 2) {
      if(type == POSITION_TYPE_BUY) {
         double newTP = currentTP + totalDistance * percent;
         if(trade.PositionModify(ticket, currentSL, NormalizeDouble(newTP, _Digits)))
            Print("Take movido - ", newTP, " - BUY");
      } else {
         double newTP = currentTP - totalDistance * percent;
         if(trade.PositionModify(ticket, currentSL, NormalizeDouble(newTP, _Digits)))
            Print("Take movido - ", newTP, " - SELL");
      }
   }

   return false;
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
    if(MAX_LOSS_ATINGIDO) {
       return false;
    }
    
    if(percentLossPerDay <= 0) {
       return true;
    }
    double max_loss_dollars = percentLossPerDay;
    
    // Calcula perda do dia (todas posições)
    double profit = AccountInfoDouble(ACCOUNT_PROFIT);
    if (profit < 0) {
       double daily_loss = AccountInfoDouble(ACCOUNT_BALANCE) -  BALANCE;
       if(profit <= -max_loss_dollars || (daily_loss < 0 && daily_loss <= -max_loss_dollars)) {
           MAX_LOSS_ATINGIDO = true;
           if(log_prefix != "") {
               Print(log_prefix, "? MAX LOSS DIÁRIO ATINGIDO! $", 
                     DoubleToString(MathAbs(profit), 2), "/", max_loss_dollars);
           }
           return false;  // Pare de operar
       }
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

   // 0 = Domingo
   // 6 = Sábado
   if (ENABLE_SATURDAY && tempo.day_of_week == 6) {
      return true;
   }
   
   if (ENABLE_MONDAY && tempo.day_of_week == 0) {
      return true;
   }
   
   if(!ENABLE_MONDAY && tempo.day_of_week == 0 && hora <= 20) {
      return false;
   }
      
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

bool GetAdx(TimeframeConfig &config) { 
   double adx[1];
   double adxPlus[1];
   double adxMinus[1];
   // Handle ADX
   int handleADX = iADX(_Symbol, config.tf, 14);
   if(handleADX == INVALID_HANDLE)
      return false;

   if(CopyBuffer(handleADX, 0, 0, 1, adx) <= 0  ||  CopyBuffer(handleADX, 2, 0, 1, adxMinus) <= 0 || CopyBuffer(handleADX, 1, 0, 1, adxPlus) <= 0)
      return false;
      
   config.adx[0] = adx[0]; 
   config.adx[1] = adxPlus[0];
   config.adx[2] = adxMinus[0];  
   return true;
}

bool GetCci(TimeframeConfig &config) { 
   // Handle ADX
   int handleCCI = iCCI(_Symbol, config.tf, 14, PRICE_TYPICAL);
   if(handleCCI == INVALID_HANDLE)
      return false;
      
   if(CopyBuffer(handleCCI, 0, 0, 15, config.cci) <= 0)
      return false;
      
   ArrayReverse(config.cci);
   return true;
}

bool GetMovingAverage(TimeframeConfig &config, int period, double &buffer[]) {   
   // Handle MA
   int handleMA = iMA(_Symbol, config.tf, period, 0, MODE_EMA, PRICE_CLOSE);
   if(handleMA == INVALID_HANDLE)
      return false;

   // Pegando últimos 3 valores da média
   if(CopyBuffer(handleMA, 0, 0, 15, buffer) <= 0)
      return false;
   
   ArrayReverse(buffer);
   return true;
}

bool GetAtr(TimeframeConfig &config) {   
   // Handle MA
   int atrHandle = iATR(_Symbol, config.tf, 14);
   if(atrHandle == INVALID_HANDLE)
      return false;
      
   if(CopyBuffer(atrHandle, 0, 0, 6, config.atr) <= 0)
      return false;

   ArrayReverse(config.atr);
   return true;
}


bool HasEnoughWinningPeriods(ENUM_POSITION_TYPE tipo, int totalQtd = 2)
{
   string periodos[];
   int totalPeriodos = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);

      if(!PositionSelectByTicket(ticket))
         continue;

      ENUM_POSITION_TYPE posTipo =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      // Mesmo tipo (BUY ou SELL)
      if(posTipo != tipo)
         continue;

      // Apenas posições em lucro
      double profit = PositionGetDouble(POSITION_PROFIT);

      if(profit <= 0)
         continue;

      string comentario =
         PositionGetString(POSITION_COMMENT);

      // Evita repetir períodos
      bool existe = false;

      for(int x = 0; x < totalPeriodos; x++)
      {
         if(periodos[x] == comentario)
         {
            existe = true;
            break;
         }
      }

      if(!existe)
      {
         ArrayResize(periodos, totalPeriodos + 1);
         periodos[totalPeriodos] = comentario;
         totalPeriodos++;
      }
   }

   return totalPeriodos > totalQtd;
}

void MoveStopByATR(TimeframeConfig &config, double multiplicador = 2.0){
   double atr = GetAverageValue(config.atr, 3);
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
      if(!IGNORE_MAGIC_NUMBER && magic != MAGIC_NUMBER)
         continue;

      UpdateTrailingStop(
         ticket,
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE),
         PositionGetDouble(POSITION_PRICE_OPEN),
         PositionGetDouble(POSITION_SL),
         PositionGetDouble(POSITION_PRICE_CURRENT),
         atr
      );
    /*  double profit = PositionGetDouble(POSITION_PROFIT);
      if(profit > 0) {

         double precoAtual = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      
         ENUM_POSITION_TYPE tipo =
            (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      
         double slAtual = PositionGetDouble(POSITION_SL);
      
         double novoSL;
      
         // Compra
         if(tipo == POSITION_TYPE_BUY)  {
            novoSL = precoAtual - (atr * multiplicador);
      
            // Só move para frente
            if(novoSL > slAtual)   {
               trade.PositionModify(ticket,
                                    novoSL,
                                    PositionGetDouble(POSITION_TP));
            }
         }
      
         // Venda
         if(tipo == POSITION_TYPE_SELL)  {
            precoAtual = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      
            novoSL = precoAtual + (atr * multiplicador);
      
            // Só move para frente
            if(slAtual == 0 || novoSL < slAtual)
            {
               trade.PositionModify(ticket,
                                    novoSL,
                                    PositionGetDouble(POSITION_TP));
            }
         }
      }*/
   }
}

bool IsNearCandleClose(TimeframeConfig &config, int minutesBeforeClose) {
   datetime candleOpenTime = iTime(_Symbol, config.tf, 0);

   if(candleOpenTime == 0)
      return false;

   int timeframeSeconds = config.tfSeconds;

   datetime candleCloseTime = candleOpenTime + timeframeSeconds;

   int secondsRemaining = (int)(candleCloseTime - TimeCurrent());

   return secondsRemaining <= (minutesBeforeClose * 60);
}

double isLateralizado(int start, int end) {
   MaximosMinimos maxMin = getMinOrMax(start, end);
   double minLow = -1;
   double minHigh = 999999999;
   double highs = 0;
   double lows = 0;
   int count = 0;
   
   for(int i = start; i < end; i++) {
      if (IsBullish(candles[i])) {
         lows += candles[i].open;
         highs += candles[i].close;
      }
      if (IsBearish(candles[i])) {
         lows += candles[i].close;
         highs += candles[i].open;
      }
   
      //lows += candles[i].low;
      //highs += candles[i].high;
      if (candles[i].low > minLow) {
         minLow = candles[i].low;
      }
      if (candles[i].high < minHigh) {
         minHigh = candles[i].high;
      }
   }
   
   int total = (end - start);
   double averageLows = lows / total;
   double averageHighs = highs / total;
   for(int i = start; i < end; i++) {
      if (candles[i].low <= averageLows && candles[i].high >= averageHighs) {
         count++;
      }
   }
   
   if (count == total) {
      return calcPoints(averageLows, averageHighs);
   }
   
   return 0;
}


void VerifyEngolfo(TimeframeConfig &config) {
   if (config.waitNewCandle) {
      return;
   }

    if(config.maxRobotsEngolfo < 0 && IsMaxRobots()) {
      return;
    }
      
   
   bool c1Bull = IsBullish(candles[0]);
   bool c2Bull = IsBullish(candles[1]);
   bool c3Bull = IsBullish(candles[2]);
   bool c4Bull = IsBullish(candles[3]);

   bool c1Bear = IsBearish(candles[0]);
   bool c2Bear = IsBearish(candles[1]);
   bool c3Bear = IsBearish(candles[2]);
   bool c4Bear = IsBearish(candles[3]);
   
   
   int initialTendency = getCandleTendecy(1, QTD_CANDLES, MIN_CANDLES_IN_TREND, true, 0);  
   if (initialTendency == 1) {
      config.actualTendency = BUY;
   } else if (initialTendency == -1) {
      config.actualTendency = SELL;
   } else {
      config.actualTendency = NONE;
   }
   
   bool active = false;
   double newVolume = NormalizeVolume(ENABLE_TIMEFRAME_MULTIPLIER ? VOLUME * config.multiplier : VOLUME);
   double precoAtual = candles[0].close;
   datetime expiration = TimeCurrent() + config.tfSeconds * 3;
   if (initialTendency == -1 && c3Bear && c4Bear && c2Bull && (config.cci[0] < CCI_MAX)) {
      config.candleCandidate = candles[0];
      config.lastCandleCandidate = candles[1];  
      config.candleCandidateTendency = BUY;
      config.candleCandidateCounter = MIN_COUNT_CANDIDATE_CANDLE;
      active = true;
   } else if(initialTendency == 1 && c3Bull && c4Bull && c2Bear && (config.cci[0] > CCI_MAX )) {
      config.candleCandidate = candles[0];
      config.lastCandleCandidate = candles[1]; 
      config.candleCandidateTendency = SELL;
      config.candleCandidateCounter = MIN_COUNT_CANDIDATE_CANDLE;
      active = true;
   }
   
   if (active) {
      active = false;
      double lastPoints = calcPoints(candles[1].open, candles[1].close);
      double secLastPoints = calcPoints(candles[2].open, candles[2].close);
      double thirdLastPoints = calcPoints(candles[3].open, candles[3].close);
      
      if (!DISABLED_NEGOTIATIONS) {
         trade.SetExpertMagicNumber(config.magicNumber);
         MaximosMinimos maxMin = getMinOrMax(1, MIN_CANDLES_IN_TREND);
         double points = calcPoints(maxMin.low, maxMin.high) * PROPORTION_TAKE_STOP;
         double tpSell = calcPrice(maxMin.low, -points);
         double tpBuy = calcPrice(maxMin.high, points);
         if ((lastPoints > secLastPoints * ACCEPTABLE_CANDLE_BODY_PERCENTUAL / 100)) {
            config.waitNewCandle = true;
            if (config.movingAverage[0] > precoAtual && config.movingAverage[1] > precoAtual && config.movingAverage[2] > precoAtual 
               // && config.adx[2] > config.adx[1]
                 ) {
               drawVerticalLine(candles[0].time, "Object_line_candleCandidato_" + EnumToString(config.tf) + "_SELL_ENGOLFO" + FormatDateToString(candles[0].time), clrRed);
               config.maxRobotsEngolfo--;
               trade.SellStop(
                  NormalizeVolume(newVolume), // volume
                  NormalizeDouble(maxMin.low, _Digits),              
                  _Symbol,
                  NormalizeDouble(maxMin.high, _Digits),
                  NormalizeDouble(tpSell, _Digits),
                  ORDER_TIME_SPECIFIED,
                  expiration,
                  "SELL_ENGOLFO_"  + config.label
               );
            }
            if (config.movingAverage[0] < precoAtual && config.movingAverage[1] < precoAtual && config.movingAverage[2] < precoAtual 
                //&& config.adx[2] < config.adx[1] 
                ) {
               config.maxRobotsEngolfo--;
               drawVerticalLine(candles[0].time, "Object_line_candleCandidato_" + EnumToString(config.tf) + "_BUY_ENGOLFO" + FormatDateToString(candles[0].time), clrWhite);
               trade.BuyStop(
                  NormalizeVolume(newVolume), // volume
                  NormalizeDouble(maxMin.high, _Digits),               
                  _Symbol,
                  NormalizeDouble(maxMin.low, _Digits),
                  NormalizeDouble(tpBuy, _Digits),
                  ORDER_TIME_SPECIFIED,
                  expiration,
                  "BUY_ENGOLFO_"  + config.label
               );
            }
        }
      }
   }
}


//+------------------------------------------------------------------+

void VerifyShortTendency(TimeframeConfig &config) {
    int index = 1;
    
    if (config.maxRobotsShortTendency < 0 && IsMaxRobots()) {
      return;
    }

   
    if (config.waitNewCandleHighRisk) {
      return;
    }
      
   datetime actualTime = candles[index].time;
   double precoAtual = candles[0].close;
   double minAnterior = candles[1].open;
   double newVolume = NormalizeVolume(ENABLE_TIMEFRAME_MULTIPLIER ? VOLUME * config.multiplier : VOLUME);
   bool diff = MathAbs(config.adx[1] - config.adx[2])  > 10;
   
   if (IsBullish(candles[2]) && IsBullish(candles[1])) {
      config.actualTendency = BUY;
   } else if (IsBearish(candles[2]) && IsBearish(candles[1])) {
      config.actualTendency = SELL;
   }  else {
      config.actualTendency = NONE;
   }
   
   if(config.actualTendency == SELL ){
     
     //--- open e mais acertivo que close
     // config.movingAverage[0] > candles[2].close && config.movingAverage[1] > candles[1].close && config.movingAverage[2] > candles[0].close 
         //&& config.adx[2] > config.adx[1]  && config.cci[0] > -CCI_MAX
         // && IsBiggerBodyThanWick(candles[1], ACCEPTABLE_CANDLE_BODY_PERCENTUAL) && IsBiggerBodyThanWick(candles[2], ACCEPTABLE_CANDLE_BODY_PERCENTUAL)
      if (config.movingAverage[1] > candles[0].high && config.movingAverage[1] > candles[1].high && config.movingAverage[2] > candles[2].high 
        && config.adx[2] > config.adx[1]  && candles[0].close < candles[1].low) {
         Print("Verificação de tendencia - ", config.label, " - SELL", " - Volume - ", newVolume);
         config.actualTendency = SELL;
         double sl = candles[2].high;
         double diff = calcPoints(precoAtual, sl) * PROPORTION_TAKE_STOP;
         double tp = NormalizeDouble(calcPrice(precoAtual, -diff), 2);
         
         if (!DISABLED_NEGOTIATIONS) {
            newVolume = NormalizeVolume(NormalizeDouble(newVolume, _Digits));
            bool ok = trade.Sell(newVolume, _Symbol, precoAtual, sl, tp, "SELL_SHORT_TENDENCY_" + config.label);
            if(ok){
               drawVerticalLine(actualTime, "Object_line_candleCandidato_" + EnumToString(config.tf) + "_SELL_CURTO_CANDIDATO" +  FormatDateToString(candles[0].time), clrRosyBrown);
               Print("SELL SHORT TENDENCY executado com sucesso em ", config.label);
               config.waitNewCandleHighRisk = true;
               config.maxRobotsShortTendency--;
            }
         }
      }
   } else  if(config.actualTendency == BUY ){
     //--- open e mais acertivo que close
     // config.movingAverage[0] < candles[2].open && config.movingAverage[1] < candles[1].open && config.movingAverage[2] < candles[0].open 
         //&& config.adx[1] > config.adx[2] && config.cci[0] < CCI_MAX
         // && IsBiggerBodyThanWick(candles[1], ACCEPTABLE_CANDLE_BODY_PERCENTUAL) && IsBiggerBodyThanWick(candles[2], ACCEPTABLE_CANDLE_BODY_PERCENTUAL)
      if (config.movingAverage[1] < candles[0].low && config.movingAverage[1] < candles[1].low && config.movingAverage[2] < candles[2].low 
         && config.adx[1] > config.adx[2] && candles[0].close > candles[1].high ) {
         Print("Verificação de tendencia - ", config.label, " - BUY", " - Volume - ", newVolume);
         config.actualTendency = BUY;
         double sl = candles[2].low;
         double diff = calcPoints(precoAtual, sl) * PROPORTION_TAKE_STOP;
         double tp = NormalizeDouble(calcPrice(precoAtual, diff), 2);
         
         
         if (!DISABLED_NEGOTIATIONS ) {
            newVolume = NormalizeVolume(NormalizeDouble(newVolume , _Digits));
           bool ok = trade.Buy(newVolume, _Symbol, precoAtual, sl, tp, "BUY_SHORT_TENDENCY_" + config.label);
           if(ok){
               drawVerticalLine(actualTime, "Object_line_candleCandidato_" + EnumToString(config.tf) + "_BUY_CURTO_CANDIDATO" +  FormatDateToString(candles[0].time), clrAqua);
               Print("BUY SHORT TENDENCY executado com sucesso em ", config.label);
               config.waitNewCandleHighRisk = true;
               config.maxRobotsEngolfo--;
           }
            
         }
      }
   }
}
//+------------------------------------------------------------------+

void VerifyTendency(TimeframeConfig &config) {
    int index = 1;

   if(config.maxRobotsTendency < 0 && IsMaxRobots()) {
      return;
   }
   
   //int min = MathRound((double)QTD_CANDLES / 2.0);
   int initialTendency = getCandleTendecy(index, QTD_CANDLES, MIN_CANDLES_IN_TREND, false, ACCEPTABLE_CANDLE_BODY_PERCENTUAL);
   datetime actualTime = candles[index].time;
   double actualBody = getBodyOrWick(candles[0], true);
   double precoAtual = candles[0].close;
   double minAnterior = candles[1].open;
   double newVolume = NormalizeVolume(ENABLE_TIMEFRAME_MULTIPLIER ? VOLUME * config.multiplier : VOLUME);
   bool diff = MathAbs(config.adx[1] - config.adx[2])  > 10;
   datetime expiration = TimeCurrent() + config.tfSeconds * 3;
   double profit = AccountInfoDouble(ACCOUNT_PROFIT);
   
   if (initialTendency == 1) {
      config.actualTendency = BUY;
   } else if (initialTendency == -1) {
      config.actualTendency = SELL;
   }  else {
      config.actualTendency = NONE;
   }
   
   if(initialTendency == -1  && diff){
      double ultimosCorposCompra = getCandleBodies(index, QTD_CANDLES, BUY);
      //IsBullish(candles[1]) && funciona
       
      if (config.movingAverage[0] > precoAtual && config.movingAverage[1] > precoAtual && config.movingAverage[2] > precoAtual 
         && config.adx[2] > config.adx[1]) {
         Print("Verificação de tendencia - ", config.label, " - SELL", " - Volume - ", newVolume);
         config.actualTendency = SELL;
         MaximosMinimos maxMin = getMinOrMax(1, QTD_CANDLES);
         double sl = maxMin.high;
         double diff = calcPoints(precoAtual, sl);
         double tp = NormalizeDouble(calcPrice(precoAtual, -diff), 2);
         
         if (diff > calcPoints(precoAtual, tp)) {
            tp = tp * PROPORTION_TAKE_STOP;
         }

         if (!DISABLED_NEGOTIATIONS) {
            if (config.cci[0] > -CCI_MAX) {
               double tendenciaExtrapolada = IsTrendSaturated(config, precoAtual);
            
               if (tendenciaExtrapolada == 0) {
                  return;
               }
               newVolume = NormalizeVolume(NormalizeDouble(newVolume * tendenciaExtrapolada, _Digits));
               ExecuteMartingale(config, SELL, candles[1], precoAtual, newVolume, sl, tp);
               bool ok = trade.Sell(newVolume, _Symbol, precoAtual, sl, tp, "SELL_TENDENCY_" + config.label);
               if(ok){
                  drawVerticalLine(actualTime, "Object_line_candleCandidato_" + EnumToString(config.tf) + "_SELL_TENDENCY_CANDIDATO" +  FormatDateToString(candles[0].time), clrViolet);
                  Print("SELL TENDENCY executado com sucesso em ", config.label);
                  config.maxRobotsTendency--;
               }
            } else {
               double sl = maxMin.low;
               double diff = calcPoints(precoAtual, sl) * PROPORTION_TAKE_STOP;
               double tp = NormalizeDouble(calcPrice(precoAtual, diff), 2);
               bool ok = trade.Buy(newVolume, _Symbol, precoAtual, sl, tp, "BUY_REVERSION_TENDENCY_" + config.label);
               if(ok){
                  drawVerticalLine(actualTime, "Object_line_candleCandidato_" + EnumToString(config.tf) + "_BUY_REVERSION_TENDENCY_CANDIDATO" +  FormatDateToString(candles[0].time), clrYellow);
                  Print("BUY REVERSION TENDENCY executado com sucesso em ", config.label);
                  config.maxRobotsTendency--;
               }
            }
         }
      }
   } else  if(initialTendency == 1 && diff ){
      drawVerticalLine(actualTime, "Object_line_candleCandidato_" + EnumToString(config.tf) + "_BUY_CANDIDATO" +  FormatDateToString(candles[0].time), clrWhite);
      double ultimosCorposVenda = getCandleBodies(index, QTD_CANDLES, SELL);
      //IsBearish(candles[1]) && funciona
      if ( config.movingAverage[0] < precoAtual && config.movingAverage[1] < precoAtual && config.movingAverage[2] < precoAtual 
         && config.adx[1] > config.adx[2]) {
         Print("Verificação de tendencia - ", config.label, " - BUY", " - Volume - ", newVolume);
         config.actualTendency = BUY;
         MaximosMinimos maxMin = getMinOrMax(1, QTD_CANDLES);
         double sl = maxMin.low;
         double diff = calcPoints(precoAtual, sl);
         double tp = NormalizeDouble(calcPrice(precoAtual, diff), 2);
         
         if (diff > calcPoints(precoAtual, tp)) {
            tp = tp * PROPORTION_TAKE_STOP;
         }
         
         if (!DISABLED_NEGOTIATIONS ) {
            if (config.cci[0] < CCI_MAX) {
               double tendenciaExtrapolada = IsTrendSaturated(config, precoAtual);
            
               if (tendenciaExtrapolada == 0) {
                  return;
               }
               newVolume = NormalizeVolume(NormalizeDouble(newVolume * tendenciaExtrapolada, _Digits));
               ExecuteMartingale(config, BUY, candles[1], precoAtual, newVolume, sl, tp);
               bool ok = trade.Buy(newVolume, _Symbol, precoAtual, sl, tp, "BUY_TENDENCY_" + config.label);
               if(ok){
                  drawVerticalLine(actualTime, "Object_line_candleCandidato_" + EnumToString(config.tf) + "_BUY_TENDENCY_CANDIDATO" +  FormatDateToString(candles[0].time), clrYellow);
                  Print("BUY TENDENCY executado com sucesso em ", config.label);
                  config.maxRobotsTendency--;
               } 
            }  else {
               double sl = maxMin.high;
               double diff = calcPoints(precoAtual, sl) * PROPORTION_TAKE_STOP;
               double tp = NormalizeDouble(calcPrice(precoAtual, -diff), 2);
               bool ok = trade.Sell(newVolume, _Symbol, precoAtual, sl, tp, "SELL_REVERSION_TENDENCY_" + config.label);
               if(ok){
                  drawVerticalLine(actualTime, "Object_line_candleCandidato_" + EnumToString(config.tf) + "_SELL_REVERSION_TENDENCY_CANDIDATO" +  FormatDateToString(candles[0].time), clrViolet);
                  Print("SELL REVERSION TENDENCY executado com sucesso em ", config.label);
                  config.maxRobotsTendency--;
               }
            }
         }
      }
   }
}

void ExecuteMartingale(TimeframeConfig &config, TYPE_NEGOCIATION type, MqlRates &candle, double precoAtual, double volume, double sl, double tp) {
   if (ENABLE_MARTINGALLE) {
      double percent = 0.50;
      while (percent > 0) {
         double body30Perc = (calcPoints(candle.close, candle.open) * percent);
         if (body30Perc > (config.atr[0] / _Point * percent)) {
            datetime expiration = TimeCurrent() + (config.tfSeconds / 2);
           // sl = calcPrice(sl, body30Perc);
            
            if (type == BUY) {
               double limitPrice = calcPrice(precoAtual, -body30Perc);
               trade.BuyLimit(
                  NormalizeVolume(volume), // volume
                  NormalizeDouble(limitPrice, _Digits),                 // preço da ordem
                  _Symbol,
                  NormalizeDouble(sl, _Digits),
                  NormalizeDouble(tp, _Digits),
                  ORDER_TIME_SPECIFIED,
                  expiration,
                  "BUY_TENDENCY_MARTINGALE_"  + config.label
               );
            } else if (type == SELL) {
               double limitPrice = calcPrice(precoAtual, body30Perc);
               trade.SellLimit(
                  NormalizeVolume(volume), // volume
                  NormalizeDouble(limitPrice, _Digits),                 // preço da ordem
                  _Symbol,
                  NormalizeDouble(sl, _Digits),
                  NormalizeDouble(tp, _Digits),
                  ORDER_TIME_SPECIFIED,
                  expiration,
                  "SELL_TENDENCY_MARTINGALE_" + config.label
               );
            }
         }
         percent -= 0.10;
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
double calcPoints(double val1, double val2, bool absValue = true) {
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(absValue)
      return NormalizeDouble(MathAbs(val1 - val2), _Digits) / point;
   else
      return NormalizeDouble((val1 - val2), _Digits) / point;
}

double GetAverageValue(double& indicator[], int qtdItems) {
   double val = 0;
   if (ArraySize(indicator) < qtdItems) {
      return 0;
   }
   
   for (int i = 0; i < qtdItems; i++) {
      val += indicator[i];
   }
   
   return val / qtdItems;
}

bool IsIndicatorTendency(double& indicator[], TYPE_NEGOCIATION type, int qtdItems) {
   int buy = 0, sell = 0;
   if (ArraySize(indicator) < qtdItems) {
      return false;
   }
   
   for (int i = 1; i < qtdItems; i++) {
      if (indicator[i] > indicator[i-1]) {
         buy++; 
      }
      
      if (indicator[i] < indicator[i-1]) {
         sell++; 
      }
   }
   
   if (type == BUY && buy == qtdItems - 1) {
      return true;
   }
   
   if (type == SELL && sell == qtdItems - 1) {
      return true;
   }
   
   return false;
}

bool IsHammerOrInvertedHammer(const MqlRates &candle) {
   double body = MathAbs(candle.close - candle.open);
   double range = candle.high - candle.low;

   if(range <= 0 || body <= 0)
      return false;

   double upperShadow = candle.high - MathMax(candle.open, candle.close);
   double lowerShadow = MathMin(candle.open, candle.close) - candle.low;

   bool hammer =
      body <= range * 0.3 &&
      lowerShadow >= body * 2.0 &&
      upperShadow <= body;

   bool invertedHammer =
      body <= range * 0.3 &&
      upperShadow >= body * 2.0 &&
      lowerShadow <= body;

   return hammer || invertedHammer;
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
   
   for(int i = start; i <= end; i++) {
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
double getCandleBodies(int start, int end, TYPE_NEGOCIATION type) {
   double bearishBody = 0;
   double bullishBody = 0;
   
   for(int i = start; i < end; i++) {
      if(IsBearish(candles[i])) {
         bearishBody += getBodyOrWick(candles[i], true);
      } else if(IsBullish(candles[i])) {
         bullishBody += getBodyOrWick(candles[i], true);
      }
   }

   if (type == BUY) {
      return bullishBody;
   }
   else if(type == SELL) {
      return bearishBody;
   }
   
   return 0;
}

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

bool IsBiggerBodyThanWick(MqlRates &candle, double acceptableBody) {
  double body = getBodyOrWick(candle, true);
  double wick = getBodyOrWick(candle, false);
  
  return body * acceptableBody / 100 > wick;
}

void UpdateTrailingStop(ulong ticket,
                        ENUM_POSITION_TYPE positionType,
                        double openPrice,
                        double currentSL,
                        double currentPrice,
                        double atr)
{
   if(!PositionSelectByTicket(ticket))
      return;

   double profitPoints;
   double profitATR;
   double newSL = currentSL;
   double tp = PositionGetDouble(POSITION_TP);

   if(positionType == POSITION_TYPE_BUY)
   {
      profitPoints = currentPrice - openPrice;
      profitATR = profitPoints / atr;

      // Menos de 2 ATR: não faz nada
      if(profitATR < 2.0)
         return;

      // Entre 2 e 4 ATR: Break Even
      if(profitATR < 4.0)
      {
         newSL = openPrice;

         if(currentSL < newSL)
         {
            trade.PositionModify(
               ticket,
               NormalizeDouble(newSL, _Digits),
               tp
            );
         }

         return;
      }

      // Acima de 4 ATR: Trailing
      double trailingDistance;

      if(profitATR < 6.0)
         trailingDistance = atr * 4.0;
      else if(profitATR < 8.0)
         trailingDistance = atr * 3.0;
      else
         trailingDistance = atr * 2.0;

      newSL = currentPrice - trailingDistance;

      if(newSL > currentSL)
      {
         trade.PositionModify(
            ticket,
            NormalizeDouble(newSL, _Digits),
            tp
         );
      }
   }
   else if(positionType == POSITION_TYPE_SELL)
   {
      profitPoints = openPrice - currentPrice;
      profitATR = profitPoints / atr;

      // Menos de 2 ATR: não faz nada
      if(profitATR < 2.0)
         return;

      // Entre 2 e 4 ATR: Break Even
      if(profitATR < 4.0)
      {
         newSL = openPrice;

         if(currentSL == 0 || currentSL > newSL)
         {
            trade.PositionModify(
               ticket,
               NormalizeDouble(newSL, _Digits),
               tp
            );
         }

         return;
      }

      // Acima de 4 ATR: Trailing
      double trailingDistance;

      if(profitATR < 6.0)
         trailingDistance = atr * 4.0;
      else if(profitATR < 8.0)
         trailingDistance = atr * 3.0;
      else
         trailingDistance = atr * 2.0;

      newSL = currentPrice + trailingDistance;

      if(currentSL == 0 || newSL < currentSL)
      {
         trade.PositionModify(
            ticket,
            NormalizeDouble(newSL, _Digits),
            tp
         );
      }
   }
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

double IsTrendSaturated(TimeframeConfig &config, double precoAtual){
   // distância do preço para EMA50
   double distanceMA = MathAbs(precoAtual - ((config.movingAverage[0] + config.movingAverage[1] + config.movingAverage[2]) / 3));
   
   // candle atual muito grande
   double valAdx = 0, valTendency = 0, valAtrs = 0;
   
   if(config.adx[0] > 40)
      return 0;
      
   bool isConsolidatedMA = IsMA50Consolidated(config);
   if(isConsolidatedMA)
      return 0;
      
   return GetFactor(distanceMA, GetAverageValue(config.atr, 3),  ATR_MINIMUM);
}

bool IsMA50Consolidated(TimeframeConfig &config) {
   double slope = MathAbs(config.movingAverage[0] - config.movingAverage[10]);

   double maxMA = config.movingAverage[0];
   double minMA = config.movingAverage[0];

   for(int i = 0; i < 15; i++) {
      maxMA = MathMax(maxMA, config.movingAverage[i]);
      minMA = MathMin(minMA, config.movingAverage[i]);
   }

   double atr = GetAverageValue(config.atr, 3);
   return slope < atr * 0.2 && (maxMA - minMA) < atr * 0.5;
}

double GetFactor(double distanceMA, double atr, ATR_TYPE atrMinimum) {
   double minAtr = (double)atrMinimum / 10.0;
   double maxAtr = (double)ATR_5 / 10.0;

   // Percorre do maior para o menor
   double counter = 1;
   for(double i = maxAtr; i >= minAtr; i -= 1.0) {
      counter += 0.1;
      if(distanceMA > atr * i)   {
         if (i == minAtr) {
            return 1;
         } else {
            return counter;
         }
      }
   }

   return 0;
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

bool MercadoLateral(TimeframeConfig &config, double minIdx = 20, double limiteInclinacao = 0.0001) {
   // Inclinação da média (diferença simples)
   double inclinacao = config.movingAverage[0] - config.movingAverage[2];

   // Condições de lateralização
   bool maReta = MathAbs(inclinacao) < limiteInclinacao;
   bool adxFraco =  config.adx[0] < minIdx || config.adx[0] < (config.adx[1] + config.adx[2]) / 2;

   if(adxFraco) 
      return true;

   return false;
}


void generateButtons(){


      createButton("btnCloseBuy", 20, 520, 200, 30, CORNER_LEFT_LOWER, 12, "Arial", "Fechar Compras", clrWhite, clrRed, clrRed, false);
      createButton("btnCloseSell", 230, 520, 200, 30, CORNER_LEFT_LOWER, 12, "Arial", "Fechar Vendas", clrWhite, clrRed, clrRed, false);
      
       createButton("btnProtectAll", 20, 480, 240, 30, CORNER_LEFT_LOWER, 12, "Arial", "Proteger Negociações", clrWhite, clrGreen, clrGreen, false);
      createButton("btnCloseAll", 270, 480, 240, 30, CORNER_LEFT_LOWER, 12, "Arial", "Fechar Negociacoes", clrWhite, clrBlueViolet, clrBlueViolet, false);
     
}

string FormatDateToString(datetime timeValue){
   MqlDateTime dt;
   TimeToStruct(timeValue, dt);

   return StringFormat(
      "%02d/%02d/%04d %02d:%02d",
      dt.day,
      dt.mon,
      dt.year,
      dt.hour,
      dt.min
   );
}

void closeAllPositionsByType(ENUM_POSITION_TYPE type, int qtd = 0){
   int pos = PositionsTotal()-1;
   
   if(qtd > 0){
      pos = qtd;   
   }
   
   for(int i = pos; i >= 0; i--)  {
      closePositionByType(type, i);
   }
}

void closePositionByType(ENUM_POSITION_TYPE type, int i){
   if(hasPositionOpen(i)){
      ulong ticket = PositionGetTicket(i);
      PositionSelectByTicket(ticket);
      ulong magicNumber = PositionGetInteger(POSITION_MAGIC);
      if((IGNORE_MAGIC_NUMBER || MAGIC_NUMBER == magicNumber) && PositionGetInteger(POSITION_TYPE) == type){
            closeBuyOrSell(i, MAGIC_NUMBER);
      }
   }
}


void protectPositions(double points = 0){
   int pos = PositionsTotal() - 1;
   for(int i = pos; i >= 0; i--)  {
      moveStopToZeroPlusPoint(i, points);
   }
}


void  moveStopToZeroPlusPoint(int position = 0, double points = 0){
   double newSlPrice = 0;
   if(hasPositionOpen(position)){ 
      ulong ticket = PositionGetTicket(position);
      PositionSelectByTicket(ticket);
      ulong magicNumber = PositionGetInteger(POSITION_MAGIC);
      if(IGNORE_MAGIC_NUMBER || MAGIC_NUMBER == magicNumber){
         double tpPrice = PositionGetDouble(POSITION_TP);
         double slPrice = PositionGetDouble(POSITION_SL);
         double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
         
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY){
            if(slPrice < entryPrice){
               if(currentPrice > entryPrice+(points*_Point)){
                  trade.PositionModify(ticket, entryPrice+(points*_Point), tpPrice);
               }
               else{
                  trade.PositionModify(ticket, entryPrice, tpPrice);
               }
            }
         }else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL){
            if(slPrice > entryPrice){
               if(currentPrice < entryPrice-(points*_Point)){
                  trade.PositionModify(ticket, entryPrice-(points*_Point), tpPrice);
               }
               else{
                  trade.PositionModify(ticket, entryPrice, tpPrice);
               }
            }
         }
      }
   }
}

int getCandleTendecyByType(int start, int end) {
   int bearishCount = 0;
   int bullishCount = 0;
   int low = 0;
   int high = 0;
   for(int i = start; i < (start + end); i++) {
      if(IsBearish(candles[i])) {
         bearishCount++;
      }

      if( IsBullish(candles[i])) {
         bullishCount++;
      }
   }

   if(bearishCount >= end){
      return -1;
   }
   else if(bullishCount >= end) {
      return 1;
   }
   
   return 0;
}
