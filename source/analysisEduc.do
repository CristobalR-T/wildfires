/*************************************
	Project: Wildfires
	Porpurse: Wildfires-education analysis
	Author: Pedro Cubillos
*************************************/

************************************
** DIRECTORIES
************************************
clear all
set more off

if "`c(username)'"=="Pedro"{
	global data "~\Dropbox\RA_DamianClarke\Effects of Wildfires in LAC\Datasets\Education"
    global figures "~\Documents\GitHub\wildfires\results" 
	global tables "~\Documents\GitHub\wildfires\results"
}
exit 

*-------------------------------------------------------------------------------
** (1) Set dataset
*-------------------------------------------------------------------------------
use "$data/analysisEduc", clear
drop __0*

*To do: Verify "year" (test score years) and "yob" (years of birth) to use in the analysis. Also, the wildifire's date merged with students birth have to be fixed, since for many students born in 2003 there are no previous wildifires exposure in utero, because wildfire's data comes from 2003 and there is no data for 2002 or before yet. 

destring dob mob, replace
keep if year>=2012
drop if yob==2003 & mob<10
*keep if yob<2008
egen FEtime=group(yob mob)
cap egen pop=count(mrun), by(Cod_Comuna_2018 yob)

*-------------------------------------------------------------------------------
** (2) Regressions
*-------------------------------------------------------------------------------
*--------------
// Month level
*--------------
foreach HA of numlist 0 50 100 150 200 250 500 {
    preserve
    rename (upwind`HA'_month1 downwind`HA'_month1) (upwind_month1 downwind_month1)
	reghdfe mate_std upwind_month1 downwind_month1 female /*[aw=pop]*/, abs(Cod_Comuna_2018 FEtime)  cluster(rbd)
	est sto reg`HA'
	restore
}
esttab reg*, se r r2 mtitle(math_0ha math_50ha math_100ha math_150ha math_200ha math_250ha math_500ha) note(Fixed Effects by year of birth, year of standardized test, school, and municipality. Errors clustered at school level.) b(%-9.3f) se(%-9.3f) nogaps  /*label*/ starlevel ("*" 0.10 "**" 0.05 "***" 0.01) drop(female)

foreach HA of numlist 0 50 100 150 200 250 500 {
    preserve
    rename (upwind`HA'_month* downwind`HA'_month*) (upwind_month* downwind_month*)
	reghdfe mate_std upwind_month1 upwind_month2 upwind_month3 downwind_month1 downwind_month2 downwind_month3 female /*[aw=pop]*/, abs(Cod_Comuna_2018 FEtime)  cluster(rbd)
	est sto reg`HA'
	restore
}
esttab reg*, se r r2 mtitle(math_0ha math_50ha math_100ha math_150ha math_200ha math_250ha math_500ha) note(Fixed Effects by year of birth, year of standardized test, school, and municipality. Errors clustered at school level.) b(%-9.3f) se(%-9.3f) nogaps  /*label*/ starlevel ("*" 0.10 "**" 0.05 "***" 0.01) drop(female)

*-----------------
// Quartely level
*-----------------
foreach HA of numlist 0 50 100 150 200 250 500 {
    preserve
    rename (trimestreUP`HA'_lag1 trimestreDOWN`HA'_lag1) (upwind_tri1 downwind_tri1)
	reghdfe mate_std upwind_tri1 downwind_tri1 female /*[aw=pop]*/, abs(Cod_Comuna_2018 FEtime)  cluster(rbd)
	est sto reg`HA'
	restore
}
esttab reg*, se r r2 mtitle(math_0ha math_50ha math_100ha math_150ha math_200ha math_250ha math_500ha) note(Fixed Effects by year and month of birth, and municipality. Errors clustered at school level.) b(%-9.3f) se(%-9.3f) nogaps  /*label*/ starlevel ("*" 0.10 "**" 0.05 "***" 0.01) drop(female)


foreach HA of numlist 0 50 100 150 200 250 500 {
    preserve
    rename (trimestreUP`HA'_lag* trimestreDOWN`HA'_lag*) (upwind_tri* downwind_tri*)
	reghdfe mate_std upwind_tri* downwind_tri* female /*[aw=pop]*/, abs(Cod_Comuna_2018 FEtime)  cluster(rbd)
	est sto reg`HA'
	restore
}
esttab reg*, se r r2 mtitle(math_0ha math_50ha math_100ha math_150ha math_200ha math_250ha math_500ha) note(Fixed Effects by year of birth, year of standardized test, school, and municipality. Errors clustered at school level.) b(%-9.3f) se(%-9.3f) nogaps  /*label*/ starlevel ("*" 0.10 "**" 0.05 "***" 0.01) drop(female)
