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

struct RegiaoExtremo{
   double precoMin;
   double precoMax;
   double precoMedio;

   int quantidade;
   int primeiroShift;
   int ultimoShift;

   datetime primeiroTempo;
   datetime ultimoTempo;
};

struct LossTrade {
   datetime closeTime;
   double profit;
   ENUM_DEAL_TYPE type;
   double price;
};

enum VOLATILITY {
   VERY_LOW,
   LOW,
   MEDIUM,
   HIGH,
   VERY_HIGH
};

enum LOSS_TREND {
   LOSS_NONE,
   LOSS_BUY,
   LOSS_SELL,
   LOSS_BALANCED
};

enum MOVE_STOP_TYPE{
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
 
enum TypeNegotiation{
   BUY,
   SELL,
   NONE
};

enum VolumeLevel
{
   VOLUME_LOW,
   VOLUME_NORMAL,
   VOLUME_HIGH
};

struct TimeFrameCandle {
   bool win;
   bool updated;
   TypeNegotiation type;
   double volume;
   double open;
   double stop;
   double take;
   datetime time;
};

struct TimeFrameRobot {
   int maxRobots;
   int counter;
   int counterPositions;
   bool inLoss;
   bool waitNewCandle;
   TimeFrameCandle historic[10];
};

CTrade trade;
struct TimeframeConfig
{
   ENUM_TIMEFRAMES tf;
   ENUM_TIMEFRAMES tfAnterior;
   int tfSeconds;
   int cciHandle;
   double multiplier;
   datetime lastBarTime;
   TimeFrameRobot robotTendency;
   TimeFrameRobot robotAverageTendency;
   TimeFrameRobot robotEngolfoTendency;
   TimeFrameRobot robotCrossTendency;
   ulong magicNumber;
   double atr[15];
   double movingAverage[15];
   double movingAverage21[15];
   double movingAverage50[15];
   double adx[15];
   double adxMinus[15];
   double adxPlus[15];
   double cci[15];
   BordersOperation bordas;
   TypeNegotiation adxTendency;
   TypeNegotiation adxPlusTendency;
   TypeNegotiation adxMinusTendency;
   bool compraPermitida;
   bool vendaPermitida;
   string label;
   MqlRates candles[];
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

input int QTD_CANDLES = 5;
input double VOLUME = 0.01;
input double LOSS_PER_DAY = 200;
input ATR_TYPE ATR_MINIMUM = ATR_1;
input MOVE_STOP_TYPE MOVE_STOP = MOVE_STOP_30;
input double PROPORTION_TAKE_STOP = 2;
input bool ENABLE_CRUZAMENTO = true;
input bool ENABLE_ENGOLFO = true;
input bool ENABLE_MEDIAS = true;
input bool ENABLE_TENDENCIA = true;
input int NUMBER_MAX_ROBOT = 2;
input ulong MAGIC_NUMBER = 97889902933;
input bool IS_SWING_TRADE = false;
input bool IS_TEST = false;

TimeframeConfig configs[];
ENUM_TIMEFRAMES tfs[] = { PERIOD_M15};
//, PERIOD_M30,PERIOD_H1, PERIOD_H2, PERIOD_H4

int QTD_ITEMS = 15;
double POINTS_TARGET = 0;
double BALANCE = 0;
bool MAX_LOSS_ATINGIDO = false;
bool ENABLE_TIMEFRAME_MULTIPLIER = false;
bool ENABLE_ROMPIMENTO_BORDA = false;
bool NOVA_NOTICIA_AGUARDANDO = false;

//
//+------------------------------------------------------------------+
ulong GetMagicNumberByTimeframe(ENUM_TIMEFRAMES tf) {
   switch(tf)  {
      default:         return MAGIC_NUMBER;
   }
}

double TimeframeToMultiplier(ENUM_TIMEFRAMES tf){
   switch(tf) {
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
      string tfLabel = "TENDENCY_" + TimeframeToLabel(configs[i].tf);
      if(StringFind(tfComment, tfLabel) >= 0) {
         return  configs[i].tf;
      }
   }
   
   return PERIOD_MN1;
}
//+------------------------------------------------------------------+
bool IsManagedMagic(ulong magic) {
   for(int i = 0; i < ArraySize(configs); i++) {
      if(configs[i].magicNumber == magic)
         return true;
   }
   return false;
}

void recuperarEstimativasRobo(int &results[]) {
   ArrayInitialize(results, 0);
   for(int i = 0; i < ArraySize(configs); i++) {
      results[0] += configs[i].robotAverageTendency.counterPositions;
      results[1] += configs[i].robotCrossTendency.counterPositions;
      results[2] += configs[i].robotEngolfoTendency.counterPositions;
      results[3] += configs[i].robotTendency.counterPositions;
      
   }
}

void showComments(){
   double profit = AccountInfoDouble(ACCOUNT_PROFIT);
   int results[4];
   
   recuperarEstimativasRobo(results);
   Comment(
         " Total de posições ativas: ", (PositionsTotal()), 
         " Saldo: ", DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE) + profit, 2),
         " Lucro Atual: ", DoubleToString(profit, 2),
         " Tempo de Candle: ", transformarCandleTime(), "\n",
         " AverageTendency: ", results[0],
         " CrossTendency: ", results[1],
         " EngolfoTendency: ", results[2],
         " TendencyRobot: ", results[3], "\n"
         );
}

void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam){
}

//+------------------------------------------------------------------+
int OnInit() { 
   ArrayResize(configs, ArraySize(tfs));
   for(int i = 0; i < ArraySize(tfs); i++) {
      configs[i].tf = tfs[i];
      configs[i].lastBarTime = 0;
      configs[i].multiplier = TimeframeToMultiplier(tfs[i]);
      configs[i].magicNumber = GetMagicNumberByTimeframe(tfs[i]);
      configs[i].label = TimeframeToLabel(tfs[i]);
      configs[i].tfSeconds = PeriodSeconds(tfs[i]);
      configs[i].tfAnterior = i == 0 ? PERIOD_M10 : tfs[i-1];
      configs[i].bordas.max = 9999999;
      configs[i].bordas.min = 0;
      configs[i].vendaPermitida = true;
      configs[i].compraPermitida = true;
      
      iniciarRobos(configs[i].robotEngolfoTendency);
      iniciarRobos(configs[i].robotCrossTendency);
      iniciarRobos(configs[i].robotAverageTendency);
      iniciarRobos(configs[i].robotTendency);
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
      MAX_LOSS_ATINGIDO = false;
      BALANCE = AccountInfoDouble(ACCOUNT_BALANCE);
      for(int i = 0; i < ArraySize(configs); i++)  {
         configs[i].robotTendency.inLoss = false;
         configs[i].robotEngolfoTendency.inLoss = false;
         configs[i].robotAverageTendency.inLoss = false;
         configs[i].robotCrossTendency.inLoss = false;
      }
   }
   
   if(!IS_TEST) {
      showComments();
      int totalOp = PositionsTotal();
      if (totalOp > 0 && (MAX_LOSS_ATINGIDO || EmPerdaDiaria(LOSS_PER_DAY, "USD "))) {
        MAX_LOSS_ATINGIDO = true;
        printf("Perda maxima atingida.");
        closeAll();
        return;  
      }
      
      if (!IS_SWING_TRADE) {
         if (NovoCandle(PERIOD_M5)) {
            if (totalOp > 0 && SimboloVaiFechar(_Symbol, 30)) {
              printf("Mercado fechado!");
              closeAll();
              return;  
            }
            
            if (!NOVA_NOTICIA_AGUARDANDO && ExisteProximaNoticia(_Symbol, 30)) {
              printf("Noticia nos proximos 30 minutos!");
              NOVA_NOTICIA_AGUARDANDO = true;
              return;  
            }
         }
      }
   }
   
   if (MOVE_STOP != MOVE_STOP_NONE) {
      MoveStopPorPontos();
   }
   
   for(int i = 0; i < ArraySize(configs); i++)  {
      if(!GetLastClosedCandles(configs[i])) {
         printf("Candles Nao Recuperados - " + EnumToString(configs[i].tf));
         return;
      } 
      
      if (!GetMovingAverage(configs[i], MV_9, configs[i].movingAverage)) {
         printf("Media 9 Nao Recuperada - " + EnumToString(configs[i].tf));
         return;
      }   
      
      if (!GetMovingAverage(configs[i], MV_21, configs[i].movingAverage21)) {
         printf("Media 21 Nao Recuperada - " + EnumToString(configs[i].tf));
         return;
      }   
      
      if (!GetMovingAverage(configs[i], MV_50, configs[i].movingAverage50)) {
         printf("Media 50 Nao Recuperada - " + EnumToString(configs[i].tf));
         return;
      }   
      
      if (!GetAdx(configs[i])) {
         printf("ADX Nao Recuperado - " + EnumToString(configs[i].tf));
         return;
      }   
      
      if (!GetAtr(configs[i])) {
         printf("Atr Nao Recuperado - " + EnumToString(configs[i].tf));
         return;
      }
      
      if(IsNewBar(configs[i])) {
         int total = PositionsTotal();
         resetarRobo(configs[i].robotEngolfoTendency, total);
         resetarRobo(configs[i].robotAverageTendency, total);
         resetarRobo(configs[i].robotCrossTendency, total);
         resetarRobo(configs[i].robotTendency, total);
         DesenharMaximoMinimoMaisTocados(configs[i], 15, 10);
         NOVA_NOTICIA_AGUARDANDO = false;
      }
      
      if(getVolumeAtr(configs[i]) == 0) {
         return;
      }
      
      
      int remainingSeconds = calcularCandleTime(configs[i].tf);
      if (remainingSeconds < configs[i].tfSeconds * 0.4) {
         configs[i].vendaPermitida = (!VerificarTimeframeAnterior(SELL, configs[i].tfAnterior) || !verificarBordas(configs[i], SELL));
         configs[i].compraPermitida = (!VerificarTimeframeAnterior(BUY, configs[i].tfAnterior) || !verificarBordas(configs[i], BUY));
        
         if (ENABLE_ENGOLFO) {
            executarEngolfo(configs[i]);
         }
         
         if (ENABLE_MEDIAS) {
            executarMedias(configs[i]);
         }
         
         if (ENABLE_CRUZAMENTO) {
            executarCruzamento(configs[i]);
         }
         
         if (ENABLE_TENDENCIA) {
            executarTendencia(configs[i]);
         }
      }
 
   }
} 

void executarEngolfo(TimeframeConfig &config) {
   double precoAtual = config.candles[0].close;
   double highAtual = config.candles[0].high;
   double lowAtual = config.candles[0].low;
   if (invalidarExecucao(config.robotEngolfoTendency)){
      return;
   }
   
   string comentario = "robotEngolfoTendency_" + EnumToString(config.tf); 
   double lastOpen = config.candles[2].open;
   if(CandlesEmparelhados(config.tf, 3, 200)) {
      if (!TemPavioMaiorQueCorpo(config.candles[0]) && highAtual > lastOpen && highAtual > config.movingAverage21[0] && config.compraPermitida) {
         double stop = CalcularPontos(precoAtual, lastOpen);
         double take = stop * PROPORTION_TAKE_STOP;
         ExecutarNegociacao(BUY, VOLUME, stop, take, comentario, config.robotEngolfoTendency);
      } else if (!TemPavioMaiorQueCorpo(config.candles[0]) && lowAtual < lastOpen && lowAtual < config.movingAverage21[0] && config.vendaPermitida) {
         double stop = CalcularPontos(precoAtual, lastOpen);
         double take = stop * PROPORTION_TAKE_STOP;
         ExecutarNegociacao(SELL, VOLUME, stop, take, comentario, config.robotEngolfoTendency);
      }
   }
}

void executarCruzamento(TimeframeConfig &config) {
   double precoAtual = config.candles[0].close;
   double highAtual = config.candles[0].high;
   double lowAtual = config.candles[0].low;
   if (invalidarExecucao(config.robotCrossTendency)){
      return;
   }
   
   string comentario = "robotCrossTendency_" + EnumToString(config.tf);
   if(config.adxMinusTendency != NONE  && config.adxPlusTendency != NONE && config.adxMinusTendency != config.adxPlusTendency) {
      if (!TemPavioMaiorQueCorpo(config.candles[0]) && IsBearish(config.candles[0])  && config.adxMinusTendency == BUY && config.adxMinus[0] > config.adxPlus[0] && config.adxMinus[4] < config.adxPlus[4]
            && ((config.movingAverage21[0] > lowAtual && config.movingAverage[0] > lowAtual)) && config.vendaPermitida) {
         MaximosMinimos maxMin = getMinOrMax(1, 3, config);
         double stop =  CalcularPontos(maxMin.high, precoAtual);
         double take = stop * PROPORTION_TAKE_STOP;
         ExecutarNegociacao(SELL, VOLUME, stop, take, comentario, config.robotCrossTendency);
      }
      
      if (!TemPavioMaiorQueCorpo(config.candles[0]) && IsBullish(config.candles[0]) && config.adxMinusTendency == SELL  && config.adxMinus[0] < config.adxPlus[0]  && config.adxMinus[4] > config.adxPlus[4]
            && ((config.movingAverage21[0] < highAtual && config.movingAverage[0] < highAtual)) && config.compraPermitida) {
         MaximosMinimos maxMin = getMinOrMax(1, 3, config);
         double stop =  CalcularPontos(maxMin.low, precoAtual);
         double take = stop * PROPORTION_TAKE_STOP;
         ExecutarNegociacao(BUY, VOLUME, stop, take, comentario, config.robotCrossTendency);
      }
   
   }
}

void executarMedias(TimeframeConfig &config) {
   double precoAtual = config.candles[0].close;
   double highAtual = config.candles[0].high;
   double lowAtual = config.candles[0].low;
   if (invalidarExecucao(config.robotAverageTendency)){
      return;
   }
   
   string comentario = "robotAverageTendency_" + EnumToString(config.tf);
   if (!TemPavioMaiorQueCorpo(config.candles[1]) && IsBearish(config.candles[1]) && IsBearish(config.candles[0]) && config.movingAverage[2] > lowAtual  && config.movingAverage21[0] > lowAtual) {
     if (config.vendaPermitida) {
         double stop =  CalcularPontos(config.candles[1].high, precoAtual);
         double take = stop * PROPORTION_TAKE_STOP;
         ExecutarNegociacao(SELL, VOLUME, stop, take, comentario, config.robotAverageTendency);
     }
   } else if (!TemPavioMaiorQueCorpo(config.candles[1]) && IsBullish(config.candles[1]) && IsBullish(config.candles[0]) && config.movingAverage[0] < highAtual  && config.movingAverage21[0] < highAtual) {
     if (config.compraPermitida) {
         double stop =  CalcularPontos(config.candles[1].low, precoAtual);
         double take = stop * PROPORTION_TAKE_STOP;
         ExecutarNegociacao(BUY, VOLUME, stop, take, comentario, config.robotAverageTendency);
     }
   }
}

void executarTendencia(TimeframeConfig &config) {
   double precoAtual = config.candles[0].close;
   double highAtual = config.candles[0].high;
   double lowAtual = config.candles[0].low;
   if (invalidarExecucao(config.robotTendency)){
      return;
   }
   
   string comentario = "robotTendency_" + EnumToString(config.tf);
   int initialTendency = getCandleTendecy(1  , QTD_CANDLES, 1, true, 0, config);
   bool diff =  MathAbs(config.adxPlus[0] - config.adxMinus[0])  > 10;
   
   if(!TemPavioMaiorQueCorpo(config.candles[0]) && IsBearish(config.candles[0]) && initialTendency == -1  && diff){
      if (config.movingAverage[1] > lowAtual && config.movingAverage[2] > lowAtual 
         && config.adxMinus[0] > config.adxPlus[0] && config.vendaPermitida) {
         MaximosMinimos maxMin = getMinOrMax(1, QTD_CANDLES, config);
         double stop =  CalcularPontos(maxMin.high, precoAtual);
         double take = stop * PROPORTION_TAKE_STOP;
         ExecutarNegociacao(SELL, VOLUME, stop, take, comentario, config.robotTendency);
      }
   } else  if(!TemPavioMaiorQueCorpo(config.candles[0]) && IsBullish(config.candles[0]) && initialTendency == 1 && diff ){
      if (config.movingAverage[1] < highAtual && config.movingAverage[2] < highAtual 
         && config.adxPlus[0] > config.adxMinus[0] && config.compraPermitida) {
         MaximosMinimos maxMin = getMinOrMax(1, QTD_CANDLES, config);
         double stop =  CalcularPontos(maxMin.low, precoAtual);
         double take = stop * PROPORTION_TAKE_STOP;
         ExecutarNegociacao(BUY, VOLUME, stop, take, comentario, config.robotTendency);
      }
   }
}

bool ExecutarNegociacao(TypeNegotiation tipoNegociacao, double volume,  double pontosStop, double pontosTake, string comentario, TimeFrameRobot &robot) {
   if(pontosStop <= 0 || pontosTake <= 0)
      return false;
      
   if(POINTS_TARGET != 0) {
      pontosTake = pontosTake < POINTS_TARGET ? pontosTake : POINTS_TARGET;
      pontosStop = pontosStop < POINTS_TARGET ? pontosStop : POINTS_TARGET;
   }
      
   double preco = 0;
   double stop = 0;
   double take = 0;
   bool ordemExecutada = false;
   trade.SetExpertMagicNumber(MAGIC_NUMBER);
   if(tipoNegociacao == BUY) {
      preco = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      stop = preco - (pontosStop * _Point);
      take = preco + (pontosTake * _Point);

      stop = NormalizeDouble(stop, _Digits);
      take = NormalizeDouble(take, _Digits);

      if(!trade.Buy(volume,  _Symbol,  preco, stop,  take, comentario)) {
         Print("Erro ao executar compra: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
         return false;
      }
      ordemExecutada = true;
   } else if(tipoNegociacao == SELL) {
      preco = SymbolInfoDouble(_Symbol, SYMBOL_BID);

      stop = preco + (pontosStop * _Point);
      take = preco - (pontosTake * _Point);

      stop = NormalizeDouble(stop, _Digits);
      take = NormalizeDouble(take, _Digits);

      if(!trade.Sell(volume,  _Symbol,  preco, stop, take, comentario)) {
         Print("Erro ao executar venda: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
         return false;
      }
      ordemExecutada = true;
   }

   if (ordemExecutada && robot.counter >= 0) {
      if (robot.counter >= 5) {
         robot.inLoss = verificarPerdaRobo(robot, 5, preco);
      } 
      
      if (robot.counter >= ArraySize(robot.historic)) {
         robot.counter = 0;
      } 
      
      robot.waitNewCandle = true;
      robot.maxRobots--;
      robot.historic[robot.counter].volume = volume;
      robot.historic[robot.counter].time = TimeCurrent();
      robot.historic[robot.counter].type = tipoNegociacao;
      robot.historic[robot.counter].take = take;
      robot.historic[robot.counter].stop = stop;
      robot.counterPositions++;
      robot.counter++;
   }

   return false;
}

bool invalidarExecucao(TimeFrameRobot &robot) {
   if (robot.maxRobots <= 0){
      return true;
   }
   
   if (robot.waitNewCandle){
      return true;
   }
   
   if (robot.inLoss){
     // return true;
   }
   
   if (IsMaxRobots()){
      return true;
   }
   
   return false;
}

void resetarRobo(TimeFrameRobot &robot, int totalPositions) {
   robot.waitNewCandle = false;
   
   if (totalPositions == 0 && robot.maxRobots <= 0) {
      robot.maxRobots = NUMBER_MAX_ROBOT;
   }
}

double getVolumeAtr(TimeframeConfig &config) {
   double tendenciaExtrapolada = IsTrendSaturated(config);
   if (tendenciaExtrapolada == 0) {
      return 0;
   }
   
   return NormalizeDouble(VOLUME * tendenciaExtrapolada, _Digits);
}

void DesenharLinhaHorizontal(string label, double ponto, color cor) {
   string nome = label;

   // Se já existir, apenas atualiza o preço e a cor
   if(ObjectFind(0, nome) >= 0) {
      ObjectSetDouble(0, nome, OBJPROP_PRICE, ponto);
      ObjectSetInteger(0, nome, OBJPROP_COLOR, cor);
      return;
   }

   // Cria a linha
   if(ObjectCreate(0, nome, OBJ_HLINE, 0, 0, ponto)) {
      ObjectSetInteger(0, nome, OBJPROP_COLOR, cor);
      ObjectSetInteger(0, nome, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, nome, OBJPROP_STYLE, STYLE_SOLID);
   }

   ChartRedraw();
}

bool verificarBordas(TimeframeConfig &config, TypeNegotiation type) {
   double precoAtual = config.candles[0].close;\
   if (!ENABLE_ROMPIMENTO_BORDA) {
      return true;   
   }
   
   if(config.bordas.min == 0) {
      return true;
   }
   
   if (type == BUY && (precoAtual >= config.bordas.max)) {
      return true;
   }
   
   if (type == SELL && (precoAtual <= config.bordas.min)) {
      return true;
   }
   
   return false;
}

bool verificarPerdaRobo(TimeFrameRobot &robot, int max, double precoAtual) {
   int counter = 0;
   if (robot.counter < max || precoAtual == 0) {
      return false;
   }
   
   for (int i = 0; i < robot.counter; i++) {
      if (!robot.historic[i].updated) {
         if (precoAtual >= robot.historic[i].take && robot.historic[i].type == BUY) {
            robot.historic[i].updated = true;
            robot.historic[i].win = true;
         } else if (precoAtual <= robot.historic[i].take && robot.historic[i].type == SELL) {
            robot.historic[i].updated = true;
            robot.historic[i].win = true;
         }
         
         if (precoAtual >= robot.historic[i].stop && robot.historic[i].type == SELL) {
            robot.historic[i].updated = true;
            robot.historic[i].win = false;
         } else if (precoAtual <= robot.historic[i].stop && robot.historic[i].type == BUY) {
            robot.historic[i].updated = true;
            robot.historic[i].win = false;
         }
      }
      
      if (!robot.historic[i].win && robot.historic[i].updated) {
         counter++;
      }
   }
   
   return counter >= max;
}

void iniciarRobos(TimeFrameRobot &robot) {
   robot.inLoss = false;
   robot.counter = 0;
   robot.counterPositions = 0;
   robot.waitNewCandle = false;
   robot.maxRobots = NUMBER_MAX_ROBOT;
   
   for(int j = 0; j < ArraySize(robot.historic); j++) {
      robot.historic[j].type = NONE; 
      robot.historic[j].win = false;
      robot.historic[j].updated = false;
   }  
}

MaximosMinimos getMinOrMax(int start, int end, TimeframeConfig &config) {
   double high = 0;
   double low = 999999;
   double minClose = 999999;
   double minOpen = 999999;
   double maxClose = 0;
   double maxOpen = 0;
   MaximosMinimos maxMin;
   
   for(int i = start; i <= end; i++) {
      if (config.candles[i].low < low) {
         low = config.candles[i].low;
      }
      if (config.candles[i].high > high) {
         high = config.candles[i].high;
      }
      if (config.candles[i].close < minClose) {
         minClose = config.candles[i].close;
      }
      if (config.candles[i].close > maxClose) {
         maxClose = config.candles[i].close;
      }
      if (config.candles[i].open < minOpen) {
         minOpen = config.candles[i].open;
      }
      if (config.candles[i].open > maxOpen) {
         maxOpen = config.candles[i].open;
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

double CalcularPontos(double preco1, double preco2, bool isAbs = true) {
   if (isAbs) {
      return MathRound(MathAbs((preco1 - preco2) / _Point));
   }
   
   return MathRound((preco1 - preco2) / _Point);
}

bool CandlesEmparelhados(ENUM_TIMEFRAMES tf, int n, int distanciaMaximaPontos) {
   if(n < 2)
      return false;

   for(int i = n; i >= 1; i--){
      double open  = iOpen(_Symbol, tf, i);
      double close = iClose(_Symbol, tf, i);
      double high  = iHigh(_Symbol, tf, i);
      double low   = iLow(_Symbol, tf, i);

      // =====================================================
      // VERIFICA O TAMANHO DO CORPO
      // =====================================================

      double corpo = MathAbs(close - open);
      double amplitude = high - low;

      if(amplitude <= 0)
         return false;

      // Corpo precisa ter pelo menos 60% da amplitude
      if((corpo / amplitude) < 0.60)
         return false;

      // =====================================================
      // VERIFICA EMPARELHAMENTO
      // =====================================================

      if(i > 1)
      {
         double openProximo = iOpen(_Symbol, tf, i - 1);

         int distancia = (int)MathRound(
            MathAbs(close - openProximo) / _Point
         );

         if(distancia > distanciaMaximaPontos)
            return false;

         // =================================================
         // VERIFICA SE OS CANDLES ESTÃO AO CONTRÁRIO
         // =================================================

         bool candleAtualAlta = close > open;
         bool candleProximoAlta = iClose(_Symbol, tf, i - 1) >
                                  iOpen(_Symbol, tf, i - 1);

         // Os dois não podem ter a mesma direção
         if(candleAtualAlta == candleProximoAlta)
            return false;
      }
   }

   return true;
}

bool IsBullish(const MqlRates &candle) {
   return candle.close > candle.open;
}

//+------------------------------------------------------------------+
bool IsBearish(const MqlRates &candle) {
   return candle.close < candle.open;
}

//+------------------------------------------------------------------+
bool IsNewBar(TimeframeConfig &config) {
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

bool GetLastClosedCandles(TimeframeConfig &config) {
   ENUM_TIMEFRAMES tf = config.tf;
   ArraySetAsSeries(config.candles, true);

   int copied = CopyRates(_Symbol, tf, 0, QTD_CANDLES * 2, config.candles);
   if(copied < QTD_CANDLES) {
      Print("Erro ao copiar candles de ", TimeframeToLabel(tf), ". Copiados: ", copied, " Erro: ", GetLastError());
      return false;
   }

   return true;
}

bool GetAtr(TimeframeConfig &config) {   
   // Handle MA
   int atrHandle = iATR(_Symbol, config.tf, 14);
   if(atrHandle == INVALID_HANDLE)
      return false;
      
   if(CopyBuffer(atrHandle, 0, 0, QTD_ITEMS, config.atr) <= 0)
      return false;

   ArrayReverse(config.atr);
   return true;
}

bool GetAdx(TimeframeConfig &config) { 
   int handleADX = iADX(_Symbol, config.tf, 14);
   if(handleADX == INVALID_HANDLE)
      return false;

   if(CopyBuffer(handleADX, 0, 0, QTD_ITEMS, config.adx) <= 0  
      ||  CopyBuffer(handleADX, 2, 0, QTD_ITEMS, config.adxMinus) <= 0 
      || CopyBuffer(handleADX, 1, 0, QTD_ITEMS, config.adxPlus) <= 0)
      return false;
      
   ArrayReverse(config.adx);
   ArrayReverse(config.adxMinus);
   ArrayReverse(config.adxPlus);
   
   for (int i = 0; i < 3; i++) {
      config.adxTendency = ValidateListTendency(config.adx);
      config.adxMinusTendency = ValidateListTendency(config.adxMinus);
      config.adxPlusTendency = ValidateListTendency(config.adxPlus);
   }   
       
       
   return true;
}

TypeNegotiation ValidateListTendency(double &values[]) {
   int buyCount = 0, sellCount = 0, counter = 3;

   for (int i = counter+1; i > 0; i--) {
      if (values[i] > values[i-1]) {
         sellCount++;
      } else {
         buyCount++;
      }
   }  
   
   if (buyCount >= counter || (sellCount >= counter && values[0] > values[counter])) {
      return BUY;
   } 
   
   if (sellCount >= counter || (buyCount >= counter && values[0] < values[counter])) {
      return SELL;
   }
   
   return NONE;
}

double getBodyOrWick(MqlRates &candle, bool body) {
   double bodyCandle = CalcularPontos(candle.close, candle.open);
   if(body) {
      return bodyCandle;
   } 
   
   return MathAbs(bodyCandle - CalcularPontos(candle.high, candle.low));
}

int getCandleTendecy(int start, int end, int limit, bool ignoreType, double bodySize, TimeframeConfig &config) {
   int bearishCount = 0;
   int bullishCount = 0;
   int low = 0;
   int high = 0;
   for(int i = start; i < end; i++) {
      double body = getBodyOrWick(config.candles[i], true);
      double wick = getBodyOrWick(config.candles[i], false);
      
      if(i+1 < end ) {
         if(config.candles[i+1].open > config.candles[i].close 
            && body > wick * bodySize  / 100
            && config.candles[i+1].high > config.candles[i].high 
            && (ignoreType || (IsBearish(config.candles[i+1]) && IsBearish(config.candles[i])))
            ) {
            bearishCount++;
         }

         if(config.candles[i+1].open < config.candles[i].close 
            && body > wick * bodySize / 100
            && config.candles[i+1].low < config.candles[i].low 
            && (ignoreType || (IsBullish(config.candles[i+1]) && IsBullish(config.candles[i])))
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

bool GetMovingAverage(TimeframeConfig &config, int period, double &buffer[]) {   
   // Handle MA
   int handleMA = iMA(_Symbol, config.tf, period, 0, MODE_EMA, PRICE_CLOSE);
   if(handleMA == INVALID_HANDLE)
      return false;

   if(CopyBuffer(handleMA, 0, 0, QTD_ITEMS, buffer) <= 0)
      return false;
   
   ArrayReverse(buffer);
   return true;
}

bool IsMaxRobots() {
   if (NUMBER_MAX_ROBOT == 0) {
      return false;
   }

   int count = 0;
   if (ENABLE_CRUZAMENTO) {
      count++;
   }
   if (ENABLE_ENGOLFO) {
      count++;
   }
   if (ENABLE_MEDIAS) {
      count++;
   }
   if (ENABLE_TENDENCIA) {
      count++;
   }
   
   return PositionsTotal() >= NUMBER_MAX_ROBOT * count;
}

void DesenharMaximoMinimoMaisTocados(TimeframeConfig &config, int qtdCandles, int n){
   if(qtdCandles < 5)
      return;
      
      
   int min = 5;
   // =========================================================
   // PROCURA OS 3 ÚLTIMOS TOPOS
   // =========================================================

   double topos[5];
   int qtdTopos = 0;
   double fundos[5];
   int qtdFundos = 0;
   ENUM_TIMEFRAMES tf = config.tf;
   for(int i = 1; i < qtdCandles - 1 && qtdTopos < min; i++)
   {
      double openAnterior  = iOpen(_Symbol, tf, i + 1);
      double closeAnterior = iClose(_Symbol, tf, i + 1);

      double openAtual  = iOpen(_Symbol, tf, i);
      double closeAtual = iClose(_Symbol, tf, i);

      double openPosterior  = iOpen(_Symbol, tf, i - 1);
      double closePosterior = iClose(_Symbol, tf, i - 1);

      double topoAnterior  = MathMax(openAnterior, closeAnterior);
      double topoAtual     = MathMax(openAtual, closeAtual);
      double topoPosterior = MathMax(openPosterior, closePosterior);

      if(topoAtual > topoAnterior && topoAtual > topoPosterior)
      {
         topos[qtdTopos] = topoAtual;
         qtdTopos++;
      }
   }

   // =========================================================
   // PROCURA OS 3 ÚLTIMOS FUNDOS
   // =========================================================

   for(int i = 1; i < qtdCandles - 1 && qtdFundos < min; i++)
   {
      double openAnterior  = iOpen(_Symbol, tf, i + 1);
      double closeAnterior = iClose(_Symbol, tf, i + 1);

      double openAtual  = iOpen(_Symbol, tf, i);
      double closeAtual = iClose(_Symbol, tf, i);

      double openPosterior  = iOpen(_Symbol, tf, i - 1);
      double closePosterior = iClose(_Symbol, tf, i - 1);

      double fundoAnterior  = MathMin(openAnterior, closeAnterior);
      double fundoAtual     = MathMin(openAtual, closeAtual);
      double fundoPosterior = MathMin(openPosterior, closePosterior);

      if(fundoAtual < fundoAnterior && fundoAtual < fundoPosterior)
      {
         fundos[qtdFundos] = fundoAtual;
         qtdFundos++;
      }
   }

   // =========================================================
   // ENCONTRA O TOPO MAIS TOCADO
   // =========================================================

   double melhorTopo = 0;
   int maiorQuantidadeTopo = 0;

   for(int i = 0; i < qtdTopos; i++)
   {
      int quantidade = 0;

      for(int j = 0; j < qtdCandles; j++)
      {
         double open  = iOpen(_Symbol, tf, j);
         double close = iClose(_Symbol, tf, j);

         if(open == topos[i] || close == topos[i])
            quantidade++;
      }

      if(quantidade > maiorQuantidadeTopo)
      {
         maiorQuantidadeTopo = quantidade;
         melhorTopo = topos[i];
      }
   }

   // =========================================================
   // ENCONTRA O FUNDO MAIS TOCADO
   // =========================================================

   double melhorFundo = 0;
   int maiorQuantidadeFundo = 0;

   for(int i = 0; i < qtdFundos; i++)
   {
      int quantidade = 0;

      for(int j = 0; j < qtdCandles; j++)
      {
         double open  = iOpen(_Symbol, tf, j);
         double close = iClose(_Symbol, tf, j);

         if(open == fundos[i] || close == fundos[i])
            quantidade++;
      }

      if(quantidade > maiorQuantidadeFundo)
      {
         maiorQuantidadeFundo = quantidade;
         melhorFundo = fundos[i];
      }
   }

   // =========================================================
   // SE N > 0, VERIFICA QUANTOS CANDLES ESTÃO DENTRO
   // DAS DUAS BORDAS
   // =========================================================

   if(n > 0 && melhorTopo > 0 && melhorFundo > 0)
   {
      int candlesDentroDasBordas = 0;

      for(int i = 0; i < qtdCandles; i++)
      {
         double open  = iOpen(_Symbol, tf, i);
         double close = iClose(_Symbol, tf, i);

         bool openDentro =
            open >= melhorFundo &&
            open <= melhorTopo;

         bool closeDentro =
            close >= melhorFundo &&
            close <= melhorTopo;

         if(openDentro && closeDentro)
            candlesDentroDasBordas++;
      }

      // Se NÃO tiver mais de N candles dentro das bordas,
      // não desenha nenhuma das duas linhas.
      if(candlesDentroDasBordas <= n)
      {
         return;
      }
   }

   // =========================================================
   // REMOVE LINHAS ANTERIORES
   // =========================================================

   ObjectDelete(0, "BordaSuperior");
   ObjectDelete(0, "BordaInferior");

   // =========================================================
   // DESENHA TOPO MAIS TOCADO
   // =========================================================

   if(melhorTopo > 0 && melhorFundo > 0) {
      DesenharLinhaHorizontal("BordaSuperior",  melhorTopo,  clrBlue);
      DesenharLinhaHorizontal("BordaInferior",  melhorFundo,  clrBlue);
      config.bordas.min = melhorFundo;
      config.bordas.max = melhorTopo;
   }

   ChartRedraw();
}



double IsTrendSaturated(TimeframeConfig &config){
   double precoAtual = config.candles[0].close;
   if(ATR_MINIMUM == ATR_0) {
      return 1;
   }
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
            return ENABLE_TIMEFRAME_MULTIPLIER ? counter : 1;
         }
      }
   }

   return 0;
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

bool IsNewDay() {
   static datetime last_day = 0;
   datetime current_day = iTime(_Symbol, PERIOD_D1, 0);

   if(last_day != current_day) {
      last_day = current_day;
      return true;
   }
   return false;
}

string transformarCandleTime() {
   int remainingSeconds = calcularCandleTime(_Period);
   int minutes = remainingSeconds / 60;
   int seconds = remainingSeconds % 60;

   return StringFormat("%02d:%02d", minutes, seconds);
}

bool VerificarTimeframeAnterior(TypeNegotiation type, ENUM_TIMEFRAMES tf) {
   double openAtual  = iOpen(_Symbol, tf, 0);
   double closeAtual = iClose(_Symbol, tf, 0);
   
   if (type == BUY && openAtual < closeAtual){
      return true;
   }
   
   if (type == SELL && openAtual > closeAtual){
      return true;
   }
   
   return false;
}

int calcularCandleTime(ENUM_TIMEFRAMES tf) {
   datetime candleOpenTime = iTime(_Symbol, tf, 0);
   int periodSeconds = PeriodSeconds(tf);
   datetime candleCloseTime = candleOpenTime + periodSeconds;

   int remainingSeconds = (int)(candleCloseTime - TimeCurrent());

   if(remainingSeconds < 0)
      remainingSeconds = 0;
   
   return remainingSeconds;
}


bool EmPerdaDiaria(double percentLossPerDay, string log_prefix = "") {
    if(percentLossPerDay <= 0) {
       return false;
    }
    
    double max_loss_dollars = percentLossPerDay;
    double daily_loss = AccountInfoDouble(ACCOUNT_BALANCE) -  BALANCE;
    if((daily_loss < 0 && daily_loss <= -max_loss_dollars)) {
        if(log_prefix != "") {
            Print(log_prefix, "? MAX LOSS DIÁRIO ATINGIDO! $", 
                  DoubleToString(MathAbs(daily_loss), 2), "/", max_loss_dollars);
        }
        return true;  
    }
    
    return false; 
}

bool IsMarketOpenNow(int minutos = 0){
   datetime agora = TimeLocal();
      
   // Converte para estrutura
   MqlDateTime tempo;
   TimeToStruct(agora, tempo);

   int hora = tempo.hour;
   int minuto = tempo.min;

      
   if(hora >= 17 && minuto  >= 30 && hora <= 19 && minuto <= 30){   
      return false;
   }

   return true;
}


bool hasPositionOpenWithMagicNumber(int position, ulong magicNumberRobot){
   if(hasPositionOpen(position)){
      ulong ticket = PositionGetTicket(position);
      PositionSelectByTicket(ticket);
      ulong magicNumber = PositionGetInteger(POSITION_MAGIC);
      if(magicNumber <= 0 || magicNumber == magicNumberRobot){
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
}

void closeAll(){
   int total = PositionsTotal() - 1;
   for(int position = total; position >= 0; position--)  {
      closeBuyOrSell(position, MAGIC_NUMBER);
   }
}

//+------------------------------------------------------------------+
//| Move o Stop Loss por pontos                                      |
//| pontos = distância em pontos do preço atual                      |
//+------------------------------------------------------------------+
void MoveStopPorPontos() {
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   int totalPeriodos = 0, totalPeriodosMartingalle = 0, countLoss = 0;
   int total = PositionsTotal();
   double profitLoss = 0, profitWins = 0;
   bool positionsInLoss[];
   bool multRobotExecutado = false;
   
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
      if(magic > 0 && magic != MAGIC_NUMBER)
         continue;

      long type        = PositionGetInteger(POSITION_TYPE);
      double slAtual   = PositionGetDouble(POSITION_SL);
      double tpAtual   = PositionGetDouble(POSITION_TP);
      double entry     = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
      double profit = PositionGetDouble(POSITION_PROFIT);
      double volume = PositionGetDouble(POSITION_VOLUME);
      double novoSL;
      
      double percentualMoveStop = MOVE_STOP;
      double pontosTP = CalcularPontos(entry, tpAtual);
      double pontosMove = pontosTP  * percentualMoveStop / 100;
      double pontosSL = CalcularPontos(slAtual, currentPrice);
      double pontosEntrada = CalcularPontos(entry, currentPrice);
      double pontosProtecao = pontosMove * percentualMoveStop / 100;
      
      if (tpAtual <= 0) {
         tpAtual = 1000;
      }
      
      if (slAtual <= 0) {
         slAtual = 1000;
      }
      
      if (profit > 0) {
         double percentProtenction = 0.5;
         if(type == POSITION_TYPE_BUY ) {
            if (entry > slAtual || slAtual == 0) {
               if (pontosEntrada > pontosMove) {
                  novoSL = NormalizeDouble(entry + (pontosProtecao * percentProtenction * point),  _Digits);
                  if(trade.PositionModify(ticket, novoSL, tpAtual))
                     Print("Stop movido - Protecao - ", entry, " - BUY");
               } 
            } else {
               if (pontosSL > pontosMove) {
                  novoSL = NormalizeDouble(slAtual + (pontosProtecao *  percentProtenction  * point),  _Digits);
                  if(trade.PositionModify(ticket, novoSL, tpAtual))
                     Print("Stop movido - ", novoSL, " - BUY");
               }
            }
         }
   
         if(type == POSITION_TYPE_SELL) {
            if (entry < slAtual || slAtual == 0) {
               if (pontosEntrada > pontosMove) {
                  novoSL = NormalizeDouble(entry - (pontosProtecao  *  percentProtenction * point),  _Digits);
                  if(trade.PositionModify(ticket, novoSL, tpAtual))
                     Print("Stop movido - Protecao - ", entry, " - SELL");
               } 
            } else {
               if (pontosSL > pontosMove) {
                  novoSL = NormalizeDouble(slAtual - (pontosProtecao *  percentProtenction  * point),  _Digits);
                  if(trade.PositionModify(ticket, novoSL, tpAtual))
                     Print("Stop movido - ", novoSL, " - SELL");
               }
            }
         }
      }
   }
}

bool SimboloVaiFechar(string simbolo, int minutes) {
   datetime agora = TimeTradeServer();
   datetime futuro = agora + (minutes * 60);

   MqlDateTime dt;
   TimeToStruct(agora, dt);

   ENUM_DAY_OF_WEEK dia = (ENUM_DAY_OF_WEEK)dt.day_of_week;

   datetime inicio, fim;
   int sessao = 0;
   while(SymbolInfoSessionTrade(simbolo, dia, sessao, inicio, fim)) {
      sessao++;
      MqlDateTime fimSessao;
      TimeToStruct(fim, fimSessao);
      fimSessao.year = dt.year;
      fimSessao.mon  = dt.mon;
      fimSessao.day  = dt.day;
      datetime fechamento = StructToTime(fimSessao);
      if(futuro > fechamento)
         return true;
   }

   return false;
}

bool ExisteProximaNoticia(string simbolo, int minutos){
   datetime agora = TimeTradeServer();
   datetime limite = agora + (minutos * 60);

   string moedaBase   = SymbolInfoString(simbolo, SYMBOL_CURRENCY_BASE);
   string moedaProfit = SymbolInfoString(simbolo, SYMBOL_CURRENCY_PROFIT);

   if(ExisteNoticiaMoeda(moedaBase, agora, limite)) {
      return true;
   }

   if(moedaProfit != "" && moedaProfit != moedaBase) {
      if(ExisteNoticiaMoeda(moedaProfit, agora, limite)) {
         return true;
      }
   }

   return false;
}

bool ExisteNoticiaMoeda(string moeda, datetime inicio, datetime fim) {
   MqlCalendarValue valores[];

   int total = CalendarValueHistory( valores, inicio,  fim );
   if(total <= 0)
      return false;

   for(int i = 0; i < total; i++){
      MqlCalendarEvent evento;

      if(!CalendarEventById(valores[i].event_id, evento))
         continue;

      MqlCalendarCountry pais;

      if(!CalendarCountryById(evento.country_id, pais))
         continue;

      // Verifica se a notícia pertence à moeda
      if(pais.currency != moeda)
         continue;

      // Somente alto impacto
      if(evento.importance != CALENDAR_IMPORTANCE_HIGH)
         continue;

      Print(
         "Notícia encontrada: ",
         evento.name,
         " | Moeda: ", pais.currency,
         " | Horário: ",
         TimeToString(valores[i].time, TIME_DATE | TIME_MINUTES)
      );

      return true;
   }

   return false;
}

bool NovoCandle(ENUM_TIMEFRAMES timeframe){
   static datetime ultimoCandle = 0;
   datetime candleAtual = iTime(_Symbol, timeframe, 0);
   if(candleAtual == 0)
      return false;

   if(candleAtual != ultimoCandle){
      ultimoCandle = candleAtual;
      return true;
   }

   return false;
}

bool TemPavioMaiorQueCorpo(MqlRates &candle){
   double corpo = MathAbs(candle.close - candle.open);
   double pavioSuperior = candle.high - MathMax(candle.open, candle.close);
   double pavioInferior =  MathMin(candle.open, candle.close) - candle.low;

   if(pavioSuperior > 0 && pavioSuperior > corpo)
      return true;

   if(pavioInferior > 0 && pavioInferior > corpo)
      return true;

   return false;
}
