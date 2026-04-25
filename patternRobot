//+------------------------------------------------------------------+
//|                                                          CCI.mq5 |
//|                                  Copyright 2021, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2021, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"



#include <Trade\Trade.mqh>
CTrade tradeLib;

//+------------------------------------------------------------------+
//| Estrutura para posições em lucro                                 |
//+------------------------------------------------------------------+
struct PositionProfitInfo {
    ulong    ticket;
    string   symbol;
    ENUM_POSITION_TYPE type;
    double   profit;
    double   open_price;
    double   current_price;
    int      profit_points;
    datetime open_time;
};

enum AVERAGE_PONTUATION{
   AVERAGE_0,
   AVERAGE_5,
   AVERAGE_10,
   AVERAGE_15,
   AVERAGE_20,
   AVERAGE_25,
   AVERAGE_30,
};

enum TYPE_CANDLE{
   WEAK,
   STRONG,
   HAMMER,
   UNDECIDED,
};

enum OPERATOR{
   EQUAL,
   MAJOR,
   MINOR
};

enum ORIENTATION{
   UP,
   DOWN,
   MEDIUM
};

enum TYPE_NEGOCIATION{
   BUY,
   SELL,
   SELL_LIMIT,
   SELL_STOP,
   BUY_LIMIT,
   BUY_STOP,
   NONE
};

struct PositionInfo {
    ulong    magicNumber;
    double   volume;
    TYPE_NEGOCIATION type;
    double   entry;
    double   stop;
    double   take;
    datetime time;
};
enum POWER{
   ON,
   OFF
};

enum COORDINATE{
   HORIZONTAL,
   VERTICAL
};

struct CandleInfo {
   ORIENTATION orientation;
   TYPE_CANDLE type;
   double close;
   double open;
   double high;
   double low;
};

struct ResultOperation {
   double total;
   double profits;
   double losses;
   double liquidResult;
   double profitFactor;
   bool instantiated;
};

struct MainCandles {
   MqlRates actual;
   MqlRates last;
   MqlRates secondLast;
   MqlRates thirdLast;
   MqlRates getLastBiggest;
   ORIENTATION actualOrientation;
   ORIENTATION lastOrientation;
   ORIENTATION secondLastOrientation;
   ORIENTATION thirdLastOrientation;
   bool instantiated;
   double spread;
   double actualBody;
   double lastBody;
   double secondLastBody;
   double thirdLastBody;
   double actualWick;
   double lastWick;
   double secondLastWick;
   double thirdLastWick;
   double getLastBiggestBody;
   double getLastBiggestWick;
   double getLastMinimum;
   double getLastMaximum;
   
};


struct BordersOperation {
   double max;
   double min;
   double central;
   bool instantiated;
   ORIENTATION orientation;
};

struct PeriodProtectionTime {
   string dealsLimitProtection;
   string endProtection;
   string startProtection;
   bool instantiated;
};

input bool ENABLE_MARTINGALE = true;
input bool ENABLE_MOVESTOP = true;
 bool IGNORE_WAIT_CANDLE_TIME = true;
 bool ENABLE_INVERSION_POSITION = false;
ENUM_TIMEFRAMES PERIOD_MULTIPLE_POSITIONS_BY_CANDLE = PERIOD_M15;
 ENUM_TIMEFRAMES PERIOD = PERIOD_M15;
input double ACTIVE_VOLUME = 0.01;
input double PERCENT_LOSS_PER_DAY = 5;
 double MIN_BODY_POINTS = 300;   
 double PERCENTUAL_MOVE_STOP = 70;
 int NUMBER_MAX_ROBOTS = 40;
ulong MAGIC_NUMBER = 200296;
ulong IGNORED_MAGIC_NUMBER = 88888;
 int MARTINGALE_POINTS = 300;
 bool INVERT_ORDER = false;
 double LOSS_PER_DAY = 250;
 double TAKE_PROFIT = 400;
 double STOP_LOSS = 200;
 int NUMBER_ROBOTS = 5;
double BALANCE = 0;
 double LOSS_PER_OPERATION = 0;
 double PROFIT_PER_DAY = 0;
 double PROPORTION_TAKE_STOP = 2;
 string SCHEDULE_START_PROTECTION = "00:00";
 string SCHEDULE_END_PROTECTION = "00:00";

bool DISABLE_MAGIC_NUMBER = false;
 bool CALIBRATE_ORDERS = true;
int WAIT_TICKS = 0;
int WAIT_CANDLES = 0;
 int LOCK_ORDERS_BY_TYPE_IF_LOSS = 3;
 int LOCK_ORDERS_BY_SECONDS = 1000;
 int ONLY_OPEN_NEW_ORDER_AFTER = 0;
 bool EXECUTE_IFORCE = false;
 bool EXECUTE_BEARS_AND_BULLS = false;
 int MAX_CCI_VALUE = 100;
 int MAX_FORCE_VALUE = 0;
 string HORIZONTAL_LINE = "HORIZONTAL_LINE";

MqlRates candles[];
datetime actualDay = 0;
bool negociationActive = false;
MqlTick tick;                // variável para armazenar ticks 
MainCandles mainCandles;


double CCI[], IFORCE[], IBulls[], IBears[], valuePrice = 0;
int handleICCI, handleIForce, handleBears, handleBulls, countAverage = 0;
ORIENTATION orientMacro = MEDIUM;
double activeBalance= 0;
int numberMaxRobotsActive = 0, waitTicks = 0, waitCandles = 0, waitCandlesP1 = 0, waitCandlesP2 = 0, waitCandlesP3 = 0, waitCandlesP4 = 0; 
bool waitNewDay = false, dailyProfitReached = false;
int countRobots = 0, countSellOrder = 0, countBuyOrder = 0, periodAval = 5;
double profitSellOrder = 0, profitBuyOrder = 0;
ulong robots[];
int patterns[];
datetime startedDatetimeRobot;
bool sellOrdersLocked = true,  buyOrdersLocked = true, isNewDayActive= true;
PositionProfitInfo positions[];
double activeMaxRobots = 0, activeVolume = 0;
int atr_handle;


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
         closeAll(IGNORED_MAGIC_NUMBER);
      }
      if(sparam == "btnMoveStop"){
         protectPositions(15);
      }
      if(sparam == "btnBuy"){
         for(int i = 0; i < NUMBER_ROBOTS; i++){
            realizeDeals(BUY, activeVolume, STOP_LOSS, TAKE_PROFIT, IGNORED_MAGIC_NUMBER);
         }
      }
      if(sparam == "btnSell"){
         for(int i = 0; i < NUMBER_ROBOTS; i++){
            realizeDeals(SELL, activeVolume, STOP_LOSS, TAKE_PROFIT, IGNORED_MAGIC_NUMBER);
         }
      }
      
      if(sparam == "btnCloseProfit"){
         closePositionInProfit();
      }
      
      if(sparam == "btnCloseLoss"){
         closePositionInLoss();
      }
      
      if(sparam == "btnDoubleVol"){
         activeVolume *= 2;   
      }
      
      if(sparam == "btnDivVol"){
         activeVolume /= 2; 
         if(activeVolume < ACTIVE_VOLUME) {
            activeVolume = ACTIVE_VOLUME; 
         } 
      }
      
      if(sparam == "btnResetVol"){
         activeVolume = ACTIVE_VOLUME; 
      }
      
      if(sparam == "btnMvStop"){
         moveAllStopPerPoint(STOP_LOSS); 
      }
      
      if(sparam == "btnMvTake"){
         moveAllTakePerPoint(TAKE_PROFIT); 
      }
    
   }
}

//+------------------------------------------------------------------+
//                                                                          | Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   generateButtons();

   //atr_handle = iATR(_Symbol, PERIOD, 14);
   numberMaxRobotsActive = NUMBER_MAX_ROBOTS;
   startedDatetimeRobot = TimeCurrent();
   activeVolume = ACTIVE_VOLUME;
   activeMaxRobots = 1;
   countRobots = 0;
   waitCandles = 0;
   isNewDayActive = true;
   ArrayResize(robots, numberMaxRobotsActive + 10);
   ArrayResize(patterns, numberMaxRobotsActive);
   for(int i = 0; i < numberMaxRobotsActive; i++)  {
      robots[i] = MAGIC_NUMBER; 
      patterns[i] = 0;
   }
   
   
   return(INIT_SUCCEEDED);
}
  
void OnTick() {
   showComments();
   countRobots = PositionsTotal();
   
   if(!IsMarketOpenNow(_Symbol, 30)){
      closeAll();
      printf("%s Mercado fechado!", _Symbol);
      return;  // Não opera mais hoje
   }
   
    // Pare se perda diária > $100
   if(!CheckDailyMaxLoss(PERCENT_LOSS_PER_DAY, "USD ")) {
        printf("Perda maxima atingida.");
        closeAll();
        return;  // Não opera mais hoje
   }
   
    if (hasNewCandle(PERIOD_MULTIPLE_POSITIONS_BY_CANDLE)) {
       DeleteHorizontalLinesByPrefix();
       if (MARTINGALE_POINTS > 0) {
         removeObsoletesOrders();
       }
       waitCandlesP1--;
       waitCandlesP2--;
       waitCandlesP3--;
       waitCandlesP4--;
    }
    
    if (IsNewDay()){
         BALANCE = AccountInfoDouble(ACCOUNT_BALANCE);
         printf("Quantidade de engolfos realizadas: " + patterns[0]);
         printf("Quantidade de Inversoes realizadas: " + patterns[1]);
         for(int i = 0; i < numberMaxRobotsActive; i++)  {
            patterns[i] = 0;
         }
    }
   
    //double profit = AccountInfoDouble(ACCOUNT_PROFIT);
    //if( profit >= 0) {
       mainCandles = generateMainCandles();
       executePatterns(mainCandles);
    //}
   
    double activeBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    if(activeBalance > BALANCE * 1.1){
         //activeVolume += 0.01;
         BALANCE = activeBalance;
    }
    
   //protectPositionByPercentual();
   // moveAutomaticStopPerPoint acerta 60% nas configuracoes atuais
    if (ENABLE_MOVESTOP) {
      moveAutomaticStopPerPoint();
    }
}

void DeleteHorizontalLinesByPrefix() {
   int total = ObjectsTotal(0, 0, -1);

   for(int i = total - 1; i >= 0; i--) {
      string nome = ObjectName(0, i, 0, -1);
      if(nome == "") {
         continue;
      }
      
      ENUM_OBJECT tipo = (ENUM_OBJECT)ObjectGetInteger(0, nome, OBJPROP_TYPE);
      if(tipo == OBJ_HLINE && StringFind(nome, HORIZONTAL_LINE) == 0) {
         string data_str = StringSubstr(nome, StringLen(HORIZONTAL_LINE + "_Pattern_") + 1);
         datetime data = StringToTime(data_str) + getTimeInTimeFrames();
         if (TimeCurrent() > data) {
            ObjectDelete(0, nome);
         }
      }
   }

   ChartRedraw();
}

void executeMartingale(PositionInfo& position){
   if (ENABLE_MARTINGALE) {
      double newVolume = position.volume;
      double counter = MARTINGALE_POINTS; 
      ulong magicNumber = position.magicNumber;
      double stop = calcPoints(position.entry, position.stop);
      TYPE_NEGOCIATION typeDeals = position.type;
      while(counter < stop) {
         newVolume += 0.01;
         if (typeDeals == BUY) {
            double priceNorm =(mainCandles.actual.close - counter * _Point);
            double stopLoss = calcPoints(priceNorm, position.stop);
            double takeProfit = calcPoints(priceNorm, position.take);
            realizeDeals(BUY_LIMIT, newVolume, stopLoss, takeProfit , magicNumber, priceNorm);
         } else if (typeDeals == SELL) {
            double priceNorm =(mainCandles.actual.close + counter * _Point);
            double stopLoss = calcPoints(priceNorm, position.stop);
            double takeProfit = calcPoints(priceNorm, position.take);
            realizeDeals(SELL_LIMIT, newVolume, stopLoss , takeProfit , magicNumber, priceNorm);
         }
         counter += MARTINGALE_POINTS; 
      }
   }
}

void executePatterns(MainCandles& mainCandles){
   MqlRates lastCandle = mainCandles.last;
   MqlRates actualCandle = mainCandles.actual;
   MqlRates secLastCandle = mainCandles.secondLast;
   MqlRates thirdLastCandle = mainCandles.thirdLast;
   double lastBodyPoints = mainCandles.lastBody;
   double secLastBodyPoints = mainCandles.secondLastBody;
   double thirdLastBodyPoints = mainCandles.thirdLastBody;
   double actualBodyPoints = mainCandles.actualBody;
   
   if (lastBodyPoints >= MIN_BODY_POINTS && secLastBodyPoints >= MIN_BODY_POINTS && thirdLastBodyPoints >= MIN_BODY_POINTS  ) {
      ulong magicNumber = MAGIC_NUMBER;
      TYPE_NEGOCIATION type = mainCandles.actualOrientation == UP ? BUY : SELL;
      color indColor = type == UP ? clrGreenYellow : clrWhite;
      
      double closeSpread = type == UP ? calcPrice(actualCandle.close,  mainCandles.spread) : calcPrice(actualCandle.close, -mainCandles.spread);
      if (mainCandles.secondLastOrientation != mainCandles.thirdLastOrientation && mainCandles.secondLastOrientation != mainCandles.lastOrientation) {
         if ((possuiCorpoProporcional(secLastCandle, lastCandle, 10)) && waitCandlesP1 <= 0) {
            if ((type == UP && mainCandles.lastOrientation == UP && closeSpread > lastCandle.close) ){
               double sl = calcPoints(mainCandles.getLastMinimum, actualCandle.close);
               double tp = sl * PROPORTION_TAKE_STOP;
               PositionInfo position = realizeDeals(BUY, activeVolume, sl, tp , magicNumber);
               drawHorizontalLine(actualCandle.close, 0, HORIZONTAL_LINE + "_Pattern1_" + TimeToString(TimeCurrent()), indColor);
               patterns[0] += 1;
               waitCandlesP1 = 1;
               executeMartingale(position);
            }else if ((type == DOWN && mainCandles.lastOrientation == DOWN && closeSpread < lastCandle.close)){
               double sl = calcPoints(mainCandles.getLastMaximum, actualCandle.close);
               double tp = sl * PROPORTION_TAKE_STOP;
               PositionInfo position =  realizeDeals(SELL, activeVolume, sl, tp , magicNumber);
               drawHorizontalLine(actualCandle.close, 0, HORIZONTAL_LINE + "_Pattern1_" + TimeToString(TimeCurrent()), indColor);
               patterns[0] += 1;
               waitCandlesP1 = 1;
               executeMartingale(position);
            }
         }
      }
   
      // Separado faz 66%
      if (mainCandles.secondLastOrientation == mainCandles.thirdLastOrientation && mainCandles.secondLastOrientation != mainCandles.lastOrientation) {
         if (possuiCorpoProporcional(secLastCandle, lastCandle, 40) && waitCandlesP3 <= 0) {
            double sl = secLastBodyPoints;
            double tp = secLastBodyPoints * PROPORTION_TAKE_STOP;
            if (mainCandles.lastOrientation == DOWN && closeSpread < lastCandle.open){
               TYPE_NEGOCIATION newType = secLastBodyPoints > lastBodyPoints ? SELL : BUY;
               PositionInfo position = realizeDeals(newType, activeVolume, sl, tp , magicNumber);
               drawHorizontalLine(actualCandle.close, 0, HORIZONTAL_LINE + "_Pattern3_" + TimeToString(TimeCurrent()), indColor);
               patterns[1] += 1;
               waitCandlesP3 = 1;
               executeMartingale(position);
            }else if (mainCandles.lastOrientation == UP && closeSpread > lastCandle.open){
               double sl = mainCandles.secondLastBody;
               TYPE_NEGOCIATION newType = secLastBodyPoints > lastBodyPoints ? BUY : SELL;
               PositionInfo position = realizeDeals(newType, activeVolume, sl, tp , magicNumber);
               drawHorizontalLine(actualCandle.close, 0, HORIZONTAL_LINE + "_Pattern3_" + TimeToString(TimeCurrent()), indColor);
               patterns[1] += 1;
               waitCandlesP3 = 1;
               executeMartingale(position);
            }
         }
      }
   }
}

bool possuiCorpoProporcional(MqlRates& actual, MqlRates& last, double proporcao) {
   double borderMax = (actual.close + last.open) / 2;
   double borderMin = (actual.open + last.close) / 2;
   double borderBody = calcPoints(borderMax, borderMin);
   double actualBody = calcPoints(actual.open, actual.close);
   double lastBody = calcPoints(last.open, last.close);
   double propBody = ((actualBody + lastBody) / 2);
   double propActualBody = MathAbs(1 - (actualBody / propBody));
   double propLastBody = MathAbs(1 - (lastBody / propBody));
   double propBorderBody = MathAbs(1 - (borderBody / propBody));
   double percent = proporcao / 100;
   
   if ((propActualBody <= percent || propLastBody <= percent) && propBorderBody <= percent) {
      return true;
   }
   
   return false;
}

bool EhMartelo(MqlRates& candle){
   double open  = candle.open;
   double close = candle.close;
   double high  = candle.high;
   double low   = candle.low;

   double corpo         = MathAbs(close - open);
   double sombraSuperior= high - MathMax(open, close);
   double sombraInferior= MathMin(open, close) - low;
   double tamanhoTotal  = high - low;

   if(tamanhoTotal <= 0)
      return false;

   // Regras do martelo:
   // 1. corpo pequeno
   // 2. sombra inferior longa
   // 3. sombra superior curta
   bool corpoPequeno     = corpo <= (tamanhoTotal * 0.30);
   bool sombraInferLonga = sombraInferior >= (corpo * 2.0);
   bool sombraSupCurta   = sombraSuperior <= (corpo * 0.5);

   return (corpoPequeno && sombraInferLonga && sombraSupCurta);
}

void removeObsoletesOrders(){
   int position = OrdersTotal() - 1;
   for(int i = position; i >= 0; i--)  {
      ulong ticket = OrderGetTicket(position);
      OrderSelect(ticket);
      ulong magicNumber = OrderGetInteger(ORDER_MAGIC);
      if(MAGIC_NUMBER == magicNumber) {
         datetime startTime  = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
         datetime expiration = (datetime)OrderGetInteger(ORDER_TIME_EXPIRATION);
         datetime expir = startTime + getTimeInTimeFrames(); 
        
         if(TimeCurrent() >= expir) {   
            bool ok = tradeLib.OrderDelete(ticket);
            Print("Ordem expirada. Ticket=", ticket,
                  " Expiration=", TimeToString(expir, TIME_DATE|TIME_SECONDS));
         }
      }
   }
}

//+------------------------------------------------------------------+
void showComments(){
   double profit = AccountInfoDouble(ACCOUNT_PROFIT);
   Comment(
         " Total de robôs Disponiveis: ", (numberMaxRobotsActive - countRobots),
         " Total de robôs ativos: ", (countRobots), 
         " Saldo: ", DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE) + profit, 2),
         " Lucro Atual: ", DoubleToString(profit, 2),
         " Volume: ", DoubleToString(activeVolume, 2));
}

TYPE_NEGOCIATION invertOrder(TYPE_NEGOCIATION type){
   return ENABLE_INVERSION_POSITION ? (type == BUY ? SELL : BUY) : type;
}

ORIENTATION getCandleOrientantion(MqlRates& candle){
   if(candle.close > candle.open) {
      return UP;
   }
   else if(candle.close < candle.open) {
      return DOWN;
   }
   
   return MEDIUM;
}

BordersOperation normalizeTakeProfitAndStopLoss(double stopLoss, double takeProfit){
   BordersOperation borders;
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

PositionInfo toBuy(double volume, double stopLoss, double takeProfit){
   SymbolInfoTick(_Symbol, tick); 
   double stopLossNormalized = NormalizeDouble((tick.ask - stopLoss), _Digits);
   double takeProfitNormalized = NormalizeDouble((tick.ask + takeProfit), _Digits);
   double entry = NormalizeDouble(tick.ask,_Digits);
   tradeLib.Buy(volume, _Symbol, entry, stopLossNormalized, takeProfitNormalized);
   
   return createPositionInfo(entry, stopLossNormalized, takeProfitNormalized, BUY, volume);
}

PositionInfo toSell(double volume, double stopLoss, double takeProfit){
   SymbolInfoTick(_Symbol, tick);
   double stopLossNormalized = NormalizeDouble((tick.bid + stopLoss), _Digits);
   double takeProfitNormalized = NormalizeDouble((tick.bid - takeProfit), _Digits);  
   double entry = NormalizeDouble(tick.bid,_Digits);
   tradeLib.Sell(volume, _Symbol, entry, stopLossNormalized, takeProfitNormalized); 
   return createPositionInfo(entry, stopLossNormalized, takeProfitNormalized, SELL, volume);
}

PositionInfo toBuyOrder(TYPE_NEGOCIATION typeDeals, double price, double volume, double stopLoss, double takeProfit){
   double stopLossNormalized = NormalizeDouble((price - stopLoss), _Digits);
   double takeProfitNormalized = NormalizeDouble((price + takeProfit), _Digits);
   datetime expir = (datetime)TimeCurrent() + getTimeInTimeFrames();  
   double entry = NormalizeDouble(price,_Digits);
   if (typeDeals == BUY_LIMIT) {
      tradeLib.BuyLimit(volume, entry, _Symbol, stopLossNormalized, takeProfitNormalized, ORDER_TIME_GTC, expir); 
      return createPositionInfo(entry, stopLossNormalized, takeProfitNormalized, BUY_LIMIT, volume);
   } else if (typeDeals == BUY_STOP) {
      tradeLib.BuyStop(volume, entry, _Symbol, stopLossNormalized, takeProfitNormalized, ORDER_TIME_GTC, expir);  
      return createPositionInfo(entry, stopLossNormalized, takeProfitNormalized, BUY_STOP, volume);
   }
   
   return createPositionInfo(0, 0, 0, NONE, 0);
}

PositionInfo toSellOrder(TYPE_NEGOCIATION typeDeals, double price, double volume, double stopLoss, double takeProfit){
   double stopLossNormalized = NormalizeDouble((price + stopLoss), _Digits);
   double takeProfitNormalized = NormalizeDouble((price - takeProfit), _Digits);  
   datetime expir = (datetime)TimeCurrent() + getTimeInTimeFrames(); 
   double entry = NormalizeDouble(price,_Digits);
   if (typeDeals == SELL_LIMIT) {
      tradeLib.SellLimit(volume, entry, _Symbol, stopLossNormalized, takeProfitNormalized, ORDER_TIME_GTC, expir); 
      return createPositionInfo(entry, stopLossNormalized, takeProfitNormalized, SELL_LIMIT, volume);
   } else if (typeDeals == SELL_STOP) {
      tradeLib.SellStop(volume, entry, _Symbol, stopLossNormalized, takeProfitNormalized, ORDER_TIME_GTC, expir); 
      return createPositionInfo(entry, stopLossNormalized, takeProfitNormalized, SELL_STOP, volume);
   }
   
   return createPositionInfo(0, 0, 0, NONE, 0);
}

PositionInfo createPositionInfo(double entry, double sl, double tp, TYPE_NEGOCIATION type, double volume) {
   PositionInfo position;
   position.entry = entry;
   position.stop = sl;
   position.take = tp;
   position.type = type;
   position.time = TimeCurrent();
   position.volume = volume;
   position.magicNumber = MAGIC_NUMBER; 
   
   return position;
}

int getTimeInTimeFrames() {
   int time = 15 * 60;
   switch (PERIOD) {
      case PERIOD_D1:
         time = 24* 60 * 60;
         break;
      case PERIOD_H1:
         time = 60 * 60;
         break;
      case PERIOD_H4:
         time = 60 * 4 * 60;
         break;
      case PERIOD_M15:
         time = 15 * 60;
         break;
      case PERIOD_M30:
         time = 30 * 60;
         break;
      case PERIOD_M10:
         time = 10 * 60;
         break;
      case PERIOD_M12:
         time = 12 * 60;
         break;
      case PERIOD_M1:
         time = 1 * 60;
         break;
      case PERIOD_M5:
         time = 5 * 60;
         break;
   }
   
   return time;
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
      if(verifyMagicNumber(i, magicNumber) && PositionGetInteger(POSITION_TYPE) == type){
            closeBuyOrSell(i);
      }
   }
}

PositionInfo realizeDeals(TYPE_NEGOCIATION typeDeals, double volume, double stopLoss, double takeProfit, ulong magicNumber, double price = 0){
    PositionInfo position = createPositionInfo(0, 0, 0, NONE, 0);
   if(typeDeals != NONE){
      BordersOperation borders = normalizeTakeProfitAndStopLoss(stopLoss, takeProfit); 
      if (PERCENT_LOSS_PER_DAY > 0) {  
         ResultOperation result = calculateLossAndProfitExpected(); 
         if (result.losses < BALANCE * PERCENT_LOSS_PER_DAY / 100) {
            if(countRobots < numberMaxRobotsActive && hasPositionOpenWithMagicNumber(countRobots, magicNumber) == false) {
               if(typeDeals == BUY){ 
                  position = toBuy(volume, borders.min, borders.max);
               }
               else if(typeDeals == SELL){
                  position = toSell(volume, borders.min, borders.max);
               }
               else if (typeDeals == BUY_LIMIT || typeDeals == BUY_STOP) {
                  position = toBuyOrder(typeDeals, price, volume, borders.min, borders.max);
               }  
               else if (typeDeals == SELL_LIMIT || typeDeals == SELL_STOP) {
                  position = toSellOrder(typeDeals, price, volume, borders.min, borders.max);
               }  
               
               if(verifyResultTrade()){
                  tradeLib.SetExpertMagicNumber(magicNumber);
                  Print("MAGIC NUMBER: " + IntegerToString(magicNumber));
                  countRobots = PositionsTotal();
               }
             }
          }
       }
    }
    
    return position;
}

void closePositionInLoss(){
   int pos = PositionsTotal() - 1;
   for(int i = pos; i >= 0; i--)  {
      ulong ticket = PositionGetTicket(i);
      PositionSelectByTicket(ticket);
      ulong magicNumber = PositionGetInteger(POSITION_MAGIC);
      if(verifyMagicNumber(i, magicNumber)){
          double profit = PositionGetDouble(POSITION_PROFIT);
          if(profit < 0){
            closeBuyOrSell(i);
          }
      } 
   }
}

void closeBuyOrSell(int position){
   if(hasPositionOpen(position)){
      ulong ticket = PositionGetTicket(position);
      PositionSelectByTicket(ticket);
      ulong magicNumber = PositionGetInteger(POSITION_MAGIC);
      if(verifyMagicNumber(position, magicNumber)){
         tradeLib.PositionClose(ticket);
         if(verifyResultTrade()){
            Print("Negociação concluída.");
            countRobots = (countRobots-1 < 0 ? 0 : countRobots--);
         }
      }
   }
}

void closePositionInProfit(){
   int pos = PositionsTotal() - 1;
   for(int i = pos; i >= 0; i--)  {
      ulong ticket = PositionGetTicket(i);
      PositionSelectByTicket(ticket);
      ulong magicNumber = PositionGetInteger(POSITION_MAGIC);
      if(verifyMagicNumber(i, magicNumber) ){
          double profit = PositionGetDouble(POSITION_PROFIT);
          if(profit > 0){
            closeBuyOrSell(i);
          }
      } 
   }
}

bool verifyMagicNumber(int position = 0, ulong magicNumber = 0){ 
   if(DISABLE_MAGIC_NUMBER || IGNORED_MAGIC_NUMBER == magicNumber) {
      return hasPositionOpen(position);
   }
   
   if(magicNumber == 0) {
      magicNumber = MAGIC_NUMBER;
   }
   
   return hasPositionOpenWithMagicNumber(position, magicNumber);
}

void closeAll(ulong magicNumber = 0){
   int total = PositionsTotal() - 1;
   for(int position = total; position >= 0; position--)  {
      closeBuyOrSell(position, magicNumber);
   }
}

void closeBuyOrSell(int position, ulong magicNumber){
   if(hasPositionOpenWithMagicNumber(position, magicNumber)){
      ulong ticket = PositionGetTicket(position);
      tradeLib.PositionClose(ticket);
      countRobots = PositionsTotal();
      if(verifyResultTrade()){
         Print("Negociação concluída.");
      }
   }
   
   ulong ticket = OrderGetTicket(position);
   tradeLib.OrderDelete(ticket);
   if(verifyResultTrade()){
      Print("Ordem concluída.");
   }
}

bool hasPositionOpen(int position){
    string symbol = PositionGetSymbol(position);
         ulong magicNumber = PositionGetInteger(POSITION_MAGIC);
    if(PositionSelect(symbol) == true) {
      return true;       
    }
    
    return false;
}

bool verifyResultTrade(){
   if(tradeLib.ResultRetcode() == TRADE_RETCODE_PLACED || tradeLib.ResultRetcode() == TRADE_RETCODE_DONE){
      printf("Ordem de %s executada com sucesso.");
      return true;
   }else{
      Print("Erro de execução de ordem ", GetLastError());
      ResetLastError();
      return false;
   }
}

void protectPositions(double points = 0){
   int pos = PositionsTotal() - 1;
   for(int i = pos; i >= 0; i--)  {
      moveStopToZeroPlusPoint(i, points);
   }
}

ResultOperation calculateLossAndProfitExpected(){
   ResultOperation result;
   result.losses = 0;
   result.profits = 0;
   int position = OrdersTotal() - 1;
   for(int i = position; i >= 0; i--)  {
      if (hasPositionOpen(i)){ 
         ulong ticket = OrderGetTicket(i);
         PositionSelectByTicket(ticket);
         ulong magicNumber = OrderGetInteger(ORDER_MAGIC);
         if(verifyMagicNumber(i, magicNumber)){
            double tpPrice = OrderGetDouble(ORDER_TP);
            double slPrice = OrderGetDouble(ORDER_SL);
            double entryPrice = OrderGetDouble(ORDER_PRICE_OPEN);
            double volume = OrderGetDouble(ORDER_VOLUME_CURRENT);
            
            double tpPoints = calcPoints(slPrice, entryPrice, true);
            double slPoints = calcPoints(tpPrice, entryPrice, true);
            result.losses += slPoints * volume;
            result.profits += tpPoints * volume;
         }
         
      }
   }
   
   position = PositionsTotal() - 1;
   for(int i = position; i >= 0; i--)  {
      if (hasPositionOpen(i)){ 
         ulong ticket = PositionGetTicket(i);
         PositionSelectByTicket(ticket);
         ulong magicNumber = PositionGetInteger(POSITION_MAGIC);
         if(verifyMagicNumber(i, magicNumber)){
            double tpPrice = PositionGetDouble(POSITION_TP);
            double slPrice = PositionGetDouble(POSITION_SL);
            double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double volume = PositionGetDouble(POSITION_VOLUME);
            
            double tpPoints = calcPoints(slPrice, entryPrice, true);
            double slPoints = calcPoints(tpPrice, entryPrice, true);
            result.losses += slPoints * volume;
            result.profits += tpPoints * volume;
         }
         
      }
   }
   
   return result;
}

void protectPositionByPercentual(){
   int position = PositionsTotal() - 1;
   if (PERCENTUAL_MOVE_STOP > 0) {
      for(int i = position; i >= 0; i--)  {
         if(hasPositionOpen(i)){ 
            ulong ticket = PositionGetTicket(i);
            PositionSelectByTicket(ticket);
            ulong magicNumber = PositionGetInteger(POSITION_MAGIC);
            if(verifyMagicNumber(i, magicNumber)){
               double tpPrice = PositionGetDouble(POSITION_TP);
               double slPrice = PositionGetDouble(POSITION_SL);
               double profit = PositionGetDouble(POSITION_PROFIT);
               double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
               double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
               
               double totalPoints = calcPoints(tpPrice, entryPrice, true) * PERCENTUAL_MOVE_STOP / 100;
               double rescuePoints = calcPoints(tpPrice, entryPrice, true) * 20 / 100;
               double currentPoints = calcPoints(currentPrice, entryPrice, true);
               if(profit > 0 && currentPoints > totalPoints && entryPrice != slPrice){
                  if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY){
                     tradeLib.PositionModify(ticket, calcPrice(entryPrice, rescuePoints), tpPrice);
                     printf("Stop movido por porcentagem");
                  }
                           
                  if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL){
                     tradeLib.PositionModify(ticket, calcPrice(entryPrice, -rescuePoints), tpPrice);
                     printf("Stop movido por porcentagem");
                  }
               }
            }
         }
      }
   }
}

double calcPrice(double price, double points) {
   return NormalizeDouble((price + points * _Point), _Digits); ;
}

void  moveStopToZeroPlusPoint(int position = 0, double points = 0){
   double newSlPrice = 0;
   if(hasPositionOpen(position)){ 
      ulong ticket = PositionGetTicket(position);
      PositionSelectByTicket(ticket);
      ulong magicNumber = PositionGetInteger(POSITION_MAGIC);
      if(verifyMagicNumber(position, magicNumber)){
         double tpPrice = PositionGetDouble(POSITION_TP);
         double slPrice = PositionGetDouble(POSITION_SL);
         double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
         
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY){
            if(slPrice < entryPrice){
               if(currentPrice > entryPrice+(points*_Point)){
                  tradeLib.PositionModify(ticket, entryPrice+(points*_Point), tpPrice);
               }
               else{
                  tradeLib.PositionModify(ticket, entryPrice, tpPrice);
               }
            }
            if(verifyResultTrade()){
               Print("Stop movido pro zero");
            }
         }else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL){
            if(slPrice > entryPrice){
               if(currentPrice < entryPrice-(points*_Point)){
                  tradeLib.PositionModify(ticket, entryPrice-(points*_Point), tpPrice);
               }
               else{
                  tradeLib.PositionModify(ticket, entryPrice, tpPrice);
               }
            }
            if(verifyResultTrade()){
               Print("Stop movido pro zero");
            }
         }
      }
   }
}

bool hasRobotPositionOpenWithMagicNumber(ulong magicNumberRobot){
   int position = PositionsTotal() - 1;
   if(position < 0) {
      return false;
   }
   
   for(int i = position; i >= 0; i--)  {
      if(hasPositionOpen(i)){
         ulong ticket = PositionGetTicket(i);
         PositionSelectByTicket(ticket);
         ulong magicNumber = PositionGetInteger(POSITION_MAGIC);
         if(magicNumber == magicNumberRobot || magicNumberRobot == IGNORED_MAGIC_NUMBER){
            return true;
         }
      }
   }
   
   return false;
   
}

bool hasPositionOpenWithMagicNumber(int position, ulong magicNumberRobot){
   if(hasPositionOpen(position)){
      ulong ticket = PositionGetTicket(position);
      PositionSelectByTicket(ticket);
      ulong magicNumber = PositionGetInteger(POSITION_MAGIC);
      if(magicNumber == magicNumberRobot || magicNumberRobot == IGNORED_MAGIC_NUMBER){
         return true;
      }
   }
   
   return false;
   
}

bool hasNewCandle(ENUM_TIMEFRAMES period = 0){
   static datetime lastTime = 0;
   
   if(period == 0){
      period = PERIOD;
   }
   
   datetime lastBarTime = (datetime)SeriesInfoInteger(Symbol(),period,SERIES_LASTBAR_DATE);
   
   //primeira chamada da funcao
   if(lastTime == 0){
      lastTime = lastBarTime;
      return false;
   }
   
   if(lastTime != lastBarTime){
      lastTime = lastBarTime;
      return true;
   }
   
   return false;
}

void drawHorizontalLine(double price, datetime time, string nameLine, color indColor){
   ObjectCreate(ChartID(),nameLine,OBJ_HLINE,0,time,price);
   ObjectSetInteger(0,nameLine,OBJPROP_COLOR,indColor);
   ObjectSetInteger(0,nameLine,OBJPROP_WIDTH,1);
   ObjectMove(ChartID(),nameLine,0,time,price);
}

bool verifyTimeToProtection(){
   if(timeToProtection(SCHEDULE_START_PROTECTION, SCHEDULE_END_PROTECTION)){
     // Print("Horario de proteção ativo");
      return false;
   }
   return true;
}

bool timeToProtection(string startTime, string endTime){
   datetime now = TimeCurrent();
   datetime start = StringToTime(startTime);
   datetime end = StringToTime(endTime);
   
   if(startTime == "00:00" && endTime == "00:00"){
      return false;
   }else{
      if(now > start && now < end){
         return true;
      }
   }
   
   return false;
}


ORIENTATION getOrientationPerCandles(MqlRates& prev, MqlRates& actual){
   if(actual.open > prev.open){
      return UP;
   }else if(actual.open < prev.open){
      return DOWN;
   }
   
   return MEDIUM;
}


MainCandles generateMainCandles(){
   MainCandles mainCandles;
   int copiedPrice = CopyRates(_Symbol, PERIOD,0,periodAval,candles);
   if(copiedPrice == periodAval){
      mainCandles.actual = candles[periodAval-1];
      mainCandles.last = candles[periodAval-2];
      mainCandles.secondLast = candles[periodAval-3];
      mainCandles.thirdLast = candles[periodAval-4];
      mainCandles.actualOrientation = getCandleOrientantion(mainCandles.actual);
      mainCandles.lastOrientation = getCandleOrientantion(mainCandles.last);
      mainCandles.secondLastOrientation = getCandleOrientantion(mainCandles.secondLast);
      mainCandles.thirdLastOrientation = getCandleOrientantion(mainCandles.thirdLast);
      mainCandles.instantiated = true;
      mainCandles.spread = mainCandles.actual.spread;
      mainCandles.actualBody = calcPoints(mainCandles.actual.close, mainCandles.actual.open, true);
      mainCandles.lastBody = calcPoints(mainCandles.last.close, mainCandles.last.open, true);
      mainCandles.secondLastBody = calcPoints(mainCandles.secondLast.close, mainCandles.secondLast.open, true);
      mainCandles.thirdLastBody = calcPoints(mainCandles.thirdLast.close, mainCandles.thirdLast.open, true);
      mainCandles.actualWick = MathAbs(mainCandles.actualBody - calcPoints(mainCandles.actual.high, mainCandles.actual.low, true));
      mainCandles.lastWick = MathAbs(mainCandles.lastBody - calcPoints(mainCandles.last.high, mainCandles.last.low, true));
      mainCandles.secondLastWick = MathAbs(mainCandles.secondLastBody - calcPoints(mainCandles.secondLast.high, mainCandles.secondLast.low, true));
      mainCandles.thirdLastWick = MathAbs(mainCandles.thirdLastBody - calcPoints(mainCandles.thirdLast.high, mainCandles.thirdLast.low, true));
      
      mainCandles.getLastBiggest = (mainCandles.lastWick + mainCandles.lastBody) > (mainCandles.secondLastWick +  mainCandles.secondLastBody) ? mainCandles.last : mainCandles.secondLast;
      
      mainCandles.getLastBiggestWick = mainCandles.lastWick > mainCandles.secondLastWick ? (mainCandles.lastWick) : mainCandles.secondLastWick;
      mainCandles.getLastBiggestWick = mainCandles.getLastBiggestWick > mainCandles.thirdLastWick ? mainCandles.getLastBiggestWick : mainCandles.thirdLastWick;
      
      mainCandles.getLastBiggestBody = mainCandles.lastBody > mainCandles.secondLastBody ? mainCandles.lastBody : mainCandles.secondLastBody;
      mainCandles.getLastBiggestBody = mainCandles.getLastBiggestBody > mainCandles.thirdLastBody ? mainCandles.getLastBiggestBody : mainCandles.thirdLastBody;
      
      mainCandles.getLastMinimum = mainCandles.last.low < mainCandles.secondLast.low ? mainCandles.last.low : mainCandles.secondLast.low;
      mainCandles.getLastMinimum = mainCandles.getLastMinimum < mainCandles.thirdLast.low ? mainCandles.getLastMinimum : mainCandles.thirdLast.low;
      
      mainCandles.getLastMaximum = mainCandles.last.high > mainCandles.secondLast.high ? mainCandles.last.high : mainCandles.secondLast.high;
      mainCandles.getLastMaximum = mainCandles.getLastMaximum > mainCandles.thirdLast.high ? mainCandles.getLastMaximum : mainCandles.thirdLast.high;
   }else{
      mainCandles.instantiated = false;
   }
   
   return mainCandles;
}

bool isNewDay(datetime date){
   MqlDateTime structDate, structActual;
   datetime actualTime = TimeCurrent();
   
   TimeToStruct(actualTime, structActual);
   TimeToStruct(date, structDate);
   
   if((structActual.day_of_year - structDate.day_of_year) > 0){
      return true;
   }else{
      return false;
   }
}

double calcPoints(double val1, double val2, bool absValue = true){
   if(absValue){
      return MathAbs(val1 - val2) / _Point;
   }else{
      return (val1 - val2) / _Point;
   }
}

bool verifyIfSecondsIsBetterThanTimeFromPosition( long now, int position, int seconds) {
   if(position >= 0 && hasPositionOpen(position)){
      ulong ticket = PositionGetTicket(position);
      PositionSelectByTicket(ticket);
      long positionDatetime = PositionGetInteger(POSITION_TIME);
      return seconds <= ((now - positionDatetime));
   }
   
   return true;
}

double getDayProfit(datetime date) {
   double dayprof = 0.0;
   datetime end = StringToTime(TimeToString (date, TIME_DATE));
   datetime start = end - PeriodSeconds( PERIOD_D1 );
   HistorySelect(start,end);
   int TotalDeals = HistoryDealsTotal();
   for(int i = 0; i < TotalDeals; i++)  {
      ulong Ticket = HistoryDealGetTicket(i);
      if(HistoryDealGetInteger(Ticket,DEAL_ENTRY) == DEAL_ENTRY_OUT)  {
         double LatestProfit = HistoryDealGetDouble(Ticket, DEAL_PROFIT);
         dayprof += LatestProfit;
      }
   }
   return dayprof;
}

//return true se atingiu o ganho ou perda diario;
bool verifyResultPerDay(datetime date){
   double profit = getDayProfit(date);
   if(MathAbs(profit) > 0){
      if(LOSS_PER_DAY > 0 && PROFIT_PER_DAY > 0){
         if(profit > PROFIT_PER_DAY){
            printf("Lucro diario excedido: %s.", DoubleToString(profit));
            return true;
         }
         if((-profit) > LOSS_PER_DAY){
            printf("Lucro diario excedido: %s.", DoubleToString(profit));
            return true;
         }
      }
   }
   
   return false;
}

void moveAllTakePerPoint(double points){
   for(int position = PositionsTotal(); position >= 0; position--)  {
      if(hasPositionOpen(position)){
         ulong ticket = PositionGetTicket(position);
         PositionSelectByTicket(ticket);
         double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
         
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ){
            double tpPrice = PositionGetDouble(POSITION_TP);
            double newTpPrice = tpPrice + (points * _Point);
            double slPrice = PositionGetDouble(POSITION_SL);
         
            tradeLib.PositionModify(ticket, slPrice, newTpPrice);
            if(verifyResultTrade()){
               Print("Take movido");
            }
         }
         else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL ){
            double tpPrice = PositionGetDouble(POSITION_TP);
            double newTpPrice = tpPrice - (points * _Point);
            double slPrice = PositionGetDouble(POSITION_SL);
         
            tradeLib.PositionModify(ticket, slPrice,tpPrice);
            if(verifyResultTrade()){
               Print("Take movido");
            }
         }
      }
   }
}  

void moveAllStopPerPoint(double points){
   for(int position = PositionsTotal(); position >= 0; position--)  {
      if(hasPositionOpen(position)){
         ulong ticket = PositionGetTicket(position);
         PositionSelectByTicket(ticket);
         double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
         double profit = PositionGetDouble(POSITION_PROFIT);
         
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ){
            double slPrice = PositionGetDouble(POSITION_SL);
            double newSl = slPrice + (points * _Point);
            double tpPrice = PositionGetDouble(POSITION_TP);
         
            tradeLib.PositionModify(ticket, newSl,tpPrice);
            if(verifyResultTrade()){
               Print("Stop movido");
            }
         }
         else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL ){
            double slPrice = PositionGetDouble(POSITION_SL);
            double newSl = slPrice - (points * _Point);
            double tpPrice = PositionGetDouble(POSITION_TP);
         
            tradeLib.PositionModify(ticket, newSl,tpPrice);
            if(verifyResultTrade()){
               Print("Stop movido");
            }
         }
      }
   }
}  

void moveAutomaticStopPerPoint(){
   for(int position = PositionsTotal(); position >= 0; position--)  {
      if(hasPositionOpen(position)){
         ulong ticket = PositionGetTicket(position);
         PositionSelectByTicket(ticket);
         double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
         double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double profit = PositionGetDouble(POSITION_PROFIT);
         double slPrice = PositionGetDouble(POSITION_SL);
         double tpPrice = PositionGetDouble(POSITION_TP);
         double points = calcPoints(tpPrice, entryPrice) / 4;
         
         if (profit > 0) {
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
               double calculatedPrice = calcPrice(currentPrice, -points);
               if (calculatedPrice >= entryPrice && calculatedPrice >= slPrice) {
                  double newSl = slPrice + (points * _Point);
               
                  tradeLib.PositionModify(ticket, newSl, tpPrice);
                  if(verifyResultTrade()){
                     Print("Stop movido");
                  }
               }
            }
            else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) {
               double calculatedPrice = calcPrice(currentPrice, points);
               if (calculatedPrice <= entryPrice && calculatedPrice <= slPrice) {
                  double newSl = slPrice - (points * _Point);
               
                  tradeLib.PositionModify(ticket, newSl,tpPrice);
                  if(verifyResultTrade()){
                     Print("Stop movido");
                  }
               }
            }
         }
      }
   }
}  

bool bodyGreaterThanWick(MqlRates& candle){
   double body = calcPoints(candle.close, candle.open, true);
   double wick = MathAbs(body- calcPoints(candle.low, candle.high, true));
   return body >= wick;
}

void instanciateBorder(BordersOperation& borders){
     borders.max = 0;
     borders.min = 0;
     borders.central = 0;
     borders.instantiated = false;
     borders.orientation = MEDIUM;
}

//+------------------------------------------------------------------+
//| ⭐ Função principal: Retorna posições em lucro                    |
//+------------------------------------------------------------------+
int GetPositionsInProfit(ENUM_POSITION_TYPE type, PositionProfitInfo &positions[], double min_profit = 0.0) {
    ArrayFree(positions);
    int total = 0;
    
    countBuyOrder = 0;
    countSellOrder = 0;
    profitBuyOrder = 0;
    profitSellOrder = 0;
    for(int i = 0; i < PositionsTotal(); i++) {
        ulong ticket = PositionGetTicket(i);
        if(!PositionSelectByTicket(ticket)) continue;
        double profit = PositionGetDouble(POSITION_PROFIT);
         
        ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        if(pos_type == POSITION_TYPE_BUY){
            countBuyOrder++;
            profitBuyOrder += profit;
        }
        if(pos_type == POSITION_TYPE_SELL){
            countSellOrder++;
            profitSellOrder += profit;
        }
        
        if(pos_type != type) continue;
        string symbol = PositionGetString(POSITION_SYMBOL);
        double swap = PositionGetDouble(POSITION_SWAP);
        double commission = 0;
        double net_profit = profit + swap + commission;;
        
        // Só posições em lucro (acima do mínimo)
        if(net_profit <= min_profit) continue;
        
        double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
        double current_price = (pos_type == POSITION_TYPE_BUY) ? 
                              SymbolInfoDouble(symbol, SYMBOL_BID) : 
                              SymbolInfoDouble(symbol, SYMBOL_ASK);
        double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
        int profit_points = (int)((current_price - open_price) / point * 
                                 (pos_type == POSITION_TYPE_BUY ? 1 : -1));
        
        PositionProfitInfo info;
        info.ticket = ticket;
        info.symbol = symbol;
        info.type = type;
        info.profit = net_profit;
        info.open_price = open_price;
        info.current_price = current_price;
        info.profit_points = profit_points;
        info.open_time = (datetime)PositionGetInteger(POSITION_TIME);
        
        ArrayResize(positions, total + 1);
        positions[total] = info;
        total++;
    }
    
    return total;
}
//+------------------------------------------------------------------+
//| Retorna direção da tendência                                     |
//|  1  = tendência de ALTA                                          |
//| -1  = tendência de BAIXA                                         |
//|  0  = sem tendência clara                                        |
//+------------------------------------------------------------------+
int GetTrendDirection(ENUM_TIMEFRAMES tf ,
                      int ma_period = 200,
                      ENUM_MA_METHOD ma_method = MODE_SMA,
                      ENUM_APPLIED_PRICE applied = PRICE_CLOSE,
                      int shift = 0)
{
    double ma[3];
    double price[3];

    // Copia MA e preço
    if(CopyBuffer(iMA(_Symbol, tf, ma_period, 0, ma_method, applied), 0, shift, 3, ma) < 3)
        return 0;
    if(CopyClose(_Symbol, tf, shift, 3, price) < 3)
        return 0;

    // Preço atual vs MA
    double close = price[0];
    double ma_val = ma[0];

    // Regra simples
    if(close > ma_val)
        return 1;   // Alta
    else if(close < ma_val)
        return -1;  // Baixa

    return 0;       // Lateral / indefinido
}

int GetTrendADX(ENUM_TIMEFRAMES tf, int shift = 0) {
    double adx[1], di_plus[1], di_minus[1];
    
    if(CopyBuffer(iADX(_Symbol, tf, 14), 0, shift, 1, adx) < 1 ||
       CopyBuffer(iADX(_Symbol, tf, 14), 1, shift, 1, di_plus) < 1 ||
       CopyBuffer(iADX(_Symbol, tf, 14), 2, shift, 1, di_minus) < 1)
        return 0;
    
    // ADX > 25 = tendência forte
    if(adx[0] > 25.0) {
        if(di_plus[0] > di_minus[0]) return 1;   // Alta forte
        return -1;  // Baixa forte
    }
    return 0;  // Fraca/lateral
}

int GetTrendParabolicSAR(ENUM_TIMEFRAMES tf = PERIOD_CURRENT, int shift = 0) {
    double sar[2];
    if(CopyBuffer(iSAR(_Symbol, tf, 0.02, 0.2), 0, shift, 2, sar) < 2)
        return 0;
    
    double close = iClose(_Symbol, tf, shift);
    
    // SAR abaixo = alta, acima = baixa
    if(close > sar[0]) return 1;   // Alta
    if(close < sar[0]) return -1;  // Baixa
    return 0;
}

int GetTrendCombined(ENUM_TIMEFRAMES tf = PERIOD_CURRENT, int shift = 0) {
    int adx_trend = GetTrendADX(tf, shift);
    int sar_trend = GetTrendParabolicSAR(tf, shift);
    
    // Confirmação dupla
    if(adx_trend == 1 && sar_trend == 1) return 1;
    if(adx_trend == -1 && sar_trend == -1) return -1;
    
    return 0;
}

//+------------------------------------------------------------------+
//| ⭐ Detecta NOVO DIA - Retorna TRUE no 1º tick do dia              |
//+------------------------------------------------------------------+
bool IsNewDay() {
    static datetime last_day = 0;
    datetime current_day = iTime(_Symbol, PERIOD_D1, 0);  // Início do dia atual
    
    if(last_day != current_day) {
        last_day = current_day;
        return true;  // É novo dia!
    }
    return false;
}

//+------------------------------------------------------------------+
//| ⭐ Controle de MÁXIMA PERDA por DIA                               |
//| Retorna: true se ainda pode operar, false se atingiu limite       |
//+------------------------------------------------------------------+
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
            today_loss += HistoryDealGetDouble(ticket, DEAL_PROFIT);
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

// Retorna true se mercado está ABERTO (considerando antecedência em minutos)
// Ex: antecedencia=30 → fecha 30min ANTES do horário real
bool IsMarketOpenNow(string symbol, int antecedencia_minutos = 0){
   datetime now = TimeCurrent();        // horário do servidor
   MqlDateTime dt;
   TimeToStruct(now, dt);
   ENUM_DAY_OF_WEEK day = (ENUM_DAY_OF_WEEK)dt.day_of_week;

   // Horário efetivo: agora MENOS antecedência (para fechar ANTES)
   datetime check_time = now - antecedencia_minutos * 60;

   // Percorre todas as sessões do dia
   for(uint i = 0; i < 20; i++)  // Máximo típico de sessões
   {
      datetime from_time, to_time;
      if(!SymbolInfoSessionTrade(symbol, day, i, from_time, to_time))
         break;  // Não há mais sessões

      MqlDateTime dta;
      TimeToStruct(from_time, dta);
      if(dta.year < 2000){
         return true;
      }
      
      if(from_time == 0 && to_time == 0)
         continue;

      // Verifica se check_time está DENTRO da sessão
      if(check_time >= from_time && check_time < to_time)
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

void generateButtons(){

      createButton("btnCloseProfit", 20, 450, 200, 30, CORNER_LEFT_LOWER, 12, "Arial", "Fechar com lucro.", clrWhite, clrRed, clrRed, false);
      createButton("btnCloseLoss", 230, 450, 200, 30, CORNER_LEFT_LOWER, 12, "Arial", "Fechar com Perda.", clrWhite, clrRed, clrRed, false);

      createButton("btnCloseBuy", 20, 400, 200, 30, CORNER_LEFT_LOWER, 12, "Arial", "Fechar Compras", clrWhite, clrRed, clrRed, false);
      createButton("btnCloseSell", 230, 400, 200, 30, CORNER_LEFT_LOWER, 12, "Arial", "Fechar Vendas", clrWhite, clrRed, clrRed, false);
      createButton("btnCloseAll", 440, 400, 200, 30, CORNER_LEFT_LOWER, 12, "Arial", "Fechar Negociacoes", clrWhite, clrRed, clrRed, false);
      
    
       createButton("btnMoveStop", 20, 350, 240, 30, CORNER_LEFT_LOWER, 12, "Arial", "Proteger Negociações", clrWhite, clrGreen, clrGreen, false);
      createButton("btnBuy", 270, 350, 280, 30, CORNER_LEFT_LOWER, 12, "Arial", "Criar " + IntegerToString(NUMBER_ROBOTS) +" Robôs de Compra", clrWhite, clrGreen, clrGreen, false);
      createButton("btnSell", 560, 350, 260, 30, CORNER_LEFT_LOWER, 12, "Arial", "Criar " + IntegerToString(NUMBER_ROBOTS) +" Robôs de Venda", clrWhite, clrGreen, clrGreen, false);
     
      createButton("btnDoubleVol", 20, 300, 220, 30, CORNER_LEFT_LOWER, 12, "Arial", "Multip Volume por 2", clrWhite, clrBlue, clrBlue, false);
      createButton("btnDivVol", 250, 300, 220, 30, CORNER_LEFT_LOWER, 12, "Arial", "Divid Volume por 2", clrWhite, clrBlue, clrBlue, false);
      createButton("btnResetVol", 480, 300, 220, 30, CORNER_LEFT_LOWER, 12, "Arial", "Resetar Volume", clrWhite, clrBlue, clrBlue, false);
     
      createButton("btnMvTake", 20, 250, 220, 30, CORNER_LEFT_LOWER, 12, "Arial", "Aumentar Take", clrWhite, clrBlue, clrBlue, false);
      createButton("btnMvStop", 250, 250, 220, 30, CORNER_LEFT_LOWER, 12, "Arial", "Aumentar Stop", clrWhite, clrBlue, clrBlue, false);
     
}
