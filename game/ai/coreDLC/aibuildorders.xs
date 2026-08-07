//==============================================================================
/* aiBuildOrders.xs

   This file contains and selects build orders for the various civs

*/
//==============================================================================
/*
Explanation of Progress:
   - Buildings tested and mostly work
      - AI still wants to build a house
   - Home city techs drafted not tested
      - HC Cards added to decks; drafted not tested
   - gatheringOrderRule tested and works, maybe inefficiently
   - Army training not drafted
   - Research drafted not tested

*/
/*


// Keep build order globals here to keep track of them easier
extern int boBuildingArray = -1;
extern int boShipmentArray = -1;
extern int boResourceBreakdownArrayFood = -1; // These are percentages, should always be set between 0 and 100
extern int boResourceBreakdownArrayWood = -1;
extern int boResourceBreakdownArrayGold = -1;
extern int boArmyTrainArray = -1;
extern int boResearchTechArray = -1;
extern int boResearchBuilding = -1;

// Conditionals
extern int boBuildingBools = -1;
extern int boShipmentBools = -1;
extern int boResourceBools = -1;
extern int boArmyTrainBools = -1;
extern int boResearchBools = -1;

// Conditional table
// Pass "1" if you want it to always be true

// Age up stored as negative
extern const int cAge2tconditional = -11;
extern const int cAge2conditional = -12;
extern const int cAge3conditional = -13;
extern const int cAge4conditional = -14;*/

// Resource count stored as negative, less than -10. Last digit controls resource type. Max resource is currently 4000
// last digit 0: Gold
// last digit 1: Wood
// last digit 2: Food
// Room to add some more combinations of food & gold, etc
// last digit 3-9: 

// Timing
// Any number over 1 min, or: 60000. Positive for greater than, negative for less than

// Anything else, unit or tech.

bool checkConditional(int condition = 1, int indexVar = 0)
{
   int lastDigit = 0;
   int conditionalVar = xsArrayGetInt(condition, indexVar);

   // If something passes "true" make sure we return true
   if (conditionalVar == 1)
   {
      return (true);
   }

   // First look for age up conditionals
   if (conditionalVar <= -11 && conditionalVar >= -15)
   {
      if (kbGetAge() >= -1 * (conditionalVar + 11))
      {
         return (true);
      }
      else if (conditionalVar == cAge2tconditional)
      {
         if (kbGetAge() == cAge1 && agingUp() == true)
         {
            return (true);
         }
      }
   }
   // Next look at resources. Uses total resource gathered, not current value
   else if (conditionalVar < -14 && conditionalVar > -4010)
   {
      lastDigit = -1 * conditionalVar % 10;
      if (lastDigit == 0)
      {  // Gold
         if (kbTotalResourceGet(cResourceGold) > -1 * (conditionalVar + lastDigit))
         {
            return (true);
         }
      }
      else if (lastDigit == 1)
      {  // Wood
         if (kbTotalResourceGet(cResourceWood) > -1 * (conditionalVar + lastDigit))
         {
            return (true);
         }
      }
      else if (lastDigit == 2)
      {  // Food
         if (kbTotalResourceGet(cResourceFood) > -1 * (conditionalVar + lastDigit))
         {
            return (true);
         }
      }
   }
   // Next look at time, greater than or less than
   else if (conditionalVar > 60000)
   {
      if (xsGetTime() > conditionalVar)
      {
         return (true);
      }
   }
   else if (conditionalVar < -60000)
   {
      if (xsGetTime() < -1 * conditionalVar)
      {
         return (true);
      }
   }
   // Look to see if that unit exists (probably a building)
   else if (kbUnitGetHealth(conditionalVar) > 0)
   {
      return (true);
   }
   else if (kbTechGetStatus(conditionalVar) > 0)
   {
      return (true);
   }

   // Found nothing.
   return (false);

}



void createBuildOrder(void)
{
   // -----------------------
   // Define the build orders
   // -----------------------

      // Test build order

      // Buildings
      // -----------------------
      boBuildingArray = xsArrayCreateInt(3, -1, "Build order buildings list");
      xsArraySetInt(boBuildingArray, 0, cUnitTypeMarket);
      xsArraySetInt(boBuildingArray, 1, cUnitTypeLivestockPen);
      xsArraySetInt(boBuildingArray, 2, cUnitTypeMill);

      
      boBuildingBools = xsArrayCreateInt(3, 1, "Build order building bools");
      xsArraySetInt(boBuildingBools, 0, 1);
      xsArraySetInt(boBuildingBools, 1, 1);
      xsArraySetInt(boBuildingBools, 2, 1);

      // Shipments
      // -----------------------
      boShipmentArray = xsArrayCreateInt(3, -1, "Build order shipment list");
      xsArraySetInt(boShipmentArray, 0, cTechHCXPEconomicTheory);
      xsArraySetInt(boShipmentArray, 1, cTechHCStockyards);
      xsArraySetInt(boShipmentArray, 2, cTechHCAdmirality);

      boShipmentBools = xsArrayCreateInt(3, 1, "Build order shipment bools");
      xsArraySetInt(boShipmentBools, 0, 1);
      xsArraySetInt(boShipmentBools, 1, 1);
      xsArraySetInt(boShipmentBools, 2, 1);

      // Resources
      // -----------------------
      // Last resource will get overriden almost instantly
      boResourceBreakdownArrayFood = xsArrayCreateInt(3, -1, "Build order food list");
      xsArraySetInt(boResourceBreakdownArrayFood, 0, 0);
      xsArraySetInt(boResourceBreakdownArrayFood, 1, 1.0);
      xsArraySetInt(boResourceBreakdownArrayFood, 2, 0.5);

      boResourceBreakdownArrayWood = xsArrayCreateInt(3, -1, "Build order wood list");
      xsArraySetInt(boResourceBreakdownArrayWood, 0, 1.0);
      xsArraySetInt(boResourceBreakdownArrayWood, 1, 0);
      xsArraySetInt(boResourceBreakdownArrayWood, 2, 0.5);

      boResourceBreakdownArrayGold = xsArrayCreateInt(3, -1, "Build order gold list");
      xsArraySetInt(boResourceBreakdownArrayGold, 0, 0);
      xsArraySetInt(boResourceBreakdownArrayGold, 1, 0);
      xsArraySetInt(boResourceBreakdownArrayGold, 2, 0);

      boResourceBools = xsArrayCreateInt(3, 1, "Build order resource bools");
      xsArraySetInt(boResourceBools, 0, 1);
      xsArraySetInt(boResourceBools, 1, -301);
      xsArraySetInt(boResourceBools, 2, cAge2conditional);

      // Army
      // -----------------------
      boArmyTrainArray = xsArrayCreateInt(2, -1, "Build order army training list");
      xsArraySetInt(boArmyTrainArray, 0, cUnitTypeMusketeer);
      xsArraySetInt(boArmyTrainArray, 1, cUnitTypeHussar);

      boArmyTrainBools = xsArrayCreateInt(2, 1, "Build order army bools");
      xsArraySetInt(boArmyTrainBools, 0, 1);
      xsArraySetInt(boArmyTrainBools, 1, 1);

      // Techs
      // -----------------------
      boResearchTechArray = xsArrayCreateInt(2, -1, "Tech research list");
      xsArraySetInt(boResearchTechArray, 0, cTechHuntingDogs);
      xsArraySetInt(boResearchTechArray, 1, cTechGreatCoat);

      boResearchBuilding = xsArrayCreateInt(2, -1, "Tech research list");
      xsArraySetInt(boResearchBuilding, 0, gMarketUnit);
      xsArraySetInt(boResearchBuilding, 1, gMarketUnit);

      boResearchBools = xsArrayCreateInt(2, 1, "Build order research bools");
      xsArraySetInt(boResearchBools, 0, 1);
      xsArraySetInt(boResearchBools, 1, 1);


   // Select the build orders
   // to be added later
         aiChat(1, "Made Build Orders");

   return;
}

//==============================================================================
// testing
// only for testing
//==============================================================================
rule testing
inactive
minInterval 5
{
   if (boBuildingArray < 0)
   {
      createBuildOrder();
   }
   int buildingBOlength = xsArrayGetSize(boBuildingArray);
   int tempBuilding = -1;
   bool tempBool = false;
   //aiChat(1, "bool: " + xsArrayGetBool(boBuildingBools, 2));
   //aiChat(1, "buildingBOlength: " + buildingBOlength);

   for (i = 0; < buildingBOlength)
   {
      tempBuilding = xsArrayGetInt(boBuildingArray, i);
      tempBool = checkConditional(boBuildingBools, i);

      //if (checkConditional(boBuildingBools, i) == false)
      //{
         // re-evaluate bools
      //   createBuildOrder();
      //}

      aiChat(1, "#" + i + ": " + tempBool);
   }
}

//==============================================================================
// buildingBuildOrderRule
// Sets up our buildings in the queue
//==============================================================================
rule buildingBuildOrderRule
inactive
group buildOrderRules
minInterval 5
{
   int buildingBOlength = xsArrayGetSize(boBuildingArray);
   int tempBuilding = -1;

   for (i = 0; < buildingBOlength)
   {
      tempBuilding = xsArrayGetInt(boBuildingArray, i);
      if (tempBuilding > 0)
      {
         if (checkConditional(boBuildingBools, i) == true)
         {  // Adds the building to the building queue. Priority decreases slightly in case other buildings are first
            createSimpleBuildPlan(tempBuilding, 1, 100 - i, true, -1, kbBaseGetMainID(cMyID), 1);
            xsArraySetInt(boBuildingArray, i, -1);  // Delete the entry
         }
         return; // Only do one at a time
      }
      else if (i == buildingBOlength - 1)
      {  // last entry and it's -1, so time to end this rule
         xsDisableSelf();
      }
   }
}

//==============================================================================
// researchBuildOrderRule
// Sets up our techs to get researched once their conditions are fulfilled
//==============================================================================
rule researchBuildOrderRule
inactive
group buildOrderRules
minInterval 5
{
   int techBOlength = xsArrayGetSize(boResearchTechArray);
   int tempTech = -1;
   int tempBuildingType = -1;

   for (i = 0; < techBOlength)
   {
      tempTech = xsArrayGetInt(boResearchTechArray, i);
      tempBuildingType = xsArrayGetInt(boResearchBuilding, i);
      if (tempTech > 0)
      {
         if (checkConditional(boBuildingBools, i) == true)
         {  // Adds the building to the building queue. Priority decreases slightly in case others are first
            researchSimpleTech(tempTech, , -1, 100 - i);
            xsArraySetInt(boResearchTechArray, i, -1);  // Delete the entry
         }
         return; // Only do one at a time
      }
      else if (i == techBOlength - 1)
      {  // last entry and it's -1, so time to end this rule
         xsDisableSelf();
      }
   }
}

//==============================================================================
// gatheringOrderRule
// Sets up our gathering breakdown
//==============================================================================
rule gatheringOrderRule
inactive
group buildOrderRules
minInterval 5
{
   int gatheringBOLength = xsArrayGetSize(boResourceBreakdownArrayFood);
   int tempfood = -1;
   int tempwood = -1;
   int tempgold = -1;

   for (i = 0; < gatheringBOLength)
   {
      tempfood = xsArrayGetInt(boResourceBreakdownArrayFood, i);
      tempwood = xsArrayGetInt(boResourceBreakdownArrayWood, i);
      tempgold = xsArrayGetInt(boResourceBreakdownArrayGold, i);
      if (tempfood >= 0 || tempwood >= 0 || tempgold >= 0)
      {
         if (checkConditional(boResourceBools, i) == true)
         {  // Set the resource percentages
            aiChat(1, "switching resource: " + i);
            aiSetResourcePercentage(cResourceFood, false, tempfood);
            aiSetResourcePercentage(cResourceWood, false, tempwood);
            aiSetResourcePercentage(cResourceGold, false, tempgold);
            xsArraySetInt(boResourceBreakdownArrayFood, i, -1);
            xsArraySetInt(boResourceBreakdownArrayWood, i, -1);
            xsArraySetInt(boResourceBreakdownArrayGold, i, -1);
         }
         return; // Only do one at a time
      }
      else if (i == gatheringBOLength - 1)
      {  // last entry and it's -1, so time to end this rule
         aiChat(1, "resource BO over");
         xsDisableSelf();
      }
   }
}