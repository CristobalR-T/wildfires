/*************************************
	Project: Wildfires
	Porpurse: Building education dataset
	Author: Pedro Cubillos
*************************************/

************************************
** DIRECTORIES
************************************
clear all
set more off

if "`c(username)'"=="Pedro"{
	global data "~\Dropbox\RA_DamianClarke\education_data"
    global data_simce "~\Dropbox\RA_DamianClarke\education_data\simce" 
	global data_mineduc "~\Dropbox\RA_DamianClarke\education_data\matricula_mineduc"
}
exit 

************************************
** SUMMARY
************************************
 /*
 
 (1) MINEDUC - MATRICULA - BIRTH
 (2) SIMCE SCORE + FAMILY VARIABLES (in progress)
 (3) WILDFIRES: Daily level + Monthly lags & leads (in progress)
 (4) Put all data together
 
 */

*-------------------------------------------------------------------------------
** (1) MINEDUC - MATRICULA - BIRTH
*-------------------------------------------------------------------------------
/*
forvalues z=2011/2014 {
	if `z'==2010{
		import delimited "$data\Matricula-por-estudiante-`z'\20130904_matricula_unica_`z'_`z'0430_PUBL.csv", clear
		keep agno rbd cod_com_rbd mrun gen_alu fec_nac_alu edad_alu cod_com_alu nom_com_alu
		save "$data/matricula_mineduc`z'.dta", replace
	}
	if `z'<2010 {
	import delimited "$data\Matricula-por-estudiante-`z'\20140805_matricula_unica_`z'_`z'0430_PUBL.csv", clear
	keep agno rbd cod_com_rbd mrun gen_alu fec_nac_alu edad_alu cod_com_alu nom_com_alu
	save "$data/matricula_mineduc`z'.dta", replace
	}
	if `z'>2010{
	import delimited "$data\Matricula-por-estudiante-`z'\20140812_matricula_unica_`z'_`z'0430_PUBL.csv", clear
	keep agno rbd cod_com_rbd mrun gen_alu fec_nac_alu edad_alu cod_com_alu nom_com_alu
	save "$data/matricula_mineduc`z'.dta", replace
	}
}

import delimited "$data\Matricula-por-estudiante-2013\20140808_matricula_unica_2013_20130430_PUBL.csv", clear
keep agno rbd cod_com_rbd mrun gen_alu fec_nac_alu edad_alu cod_com_alu nom_com_alu
save "$data/matricula_mineduc2013.dta", replace

import delimited "$data\Matricula-por-estudiante-2014\20140924_matricula_unica_2014_20140430_PUBL.csv", clear
keep agno rbd cod_com_rbd mrun gen_alu fec_nac_alu edad_alu cod_com_alu nom_com_alu
save "$data/matricula_mineduc2014.dta", replace

import delimited "$data\Matricula-por-estudiante-2015\20150923_matricula_unica_2015_20150430_PUBL.csv", clear
keep agno rbd cod_com_rbd mrun gen_alu fec_nac_alu edad_alu cod_com_alu nom_com_alu
save "$data/matricula_mineduc2015.dta", replace

import delimited "$data\Matricula-por-estudiante-2016\20160926_matricula_unica_2016_20160430_PUBL.csv", clear
keep agno rbd cod_com_rbd mrun gen_alu fec_nac_alu edad_alu cod_com_alu nom_com_alu
save "$data/matricula_mineduc2016.dta", replace

import delimited "$data\Matricula-por-estudiante-2017\20170921_matricula_unica_2017_20170430_PUBL.csv", clear
keep agno rbd cod_com_rbd mrun gen_alu fec_nac_alu edad_alu cod_com_alu nom_com_alu
save "$data/matricula_mineduc2017.dta", replace

import delimited "$data\Matricula-por-estudiante-2018\20181005_Matrícula_unica_2018_20180430_PUBL.csv", clear
keep agno rbd cod_com_rbd mrun gen_alu fec_nac_alu edad_alu cod_com_alu nom_com_alu
save "$data/matricula_mineduc2018.dta", replace

import delimited "$data\Matricula-por-estudiante-2019\20191028_Matrícula_unica_2019_20190430_PUBL.csv", clear
keep agno rbd cod_com_rbd mrun gen_alu fec_nac_alu edad_alu cod_com_alu nom_com_alu
save "$data/matricula_mineduc2019.dta", replace

import delimited "$data\Matricula-por-estudiante-2020\20200921_Matrícula_unica_2020_20200430_WEB.csv", clear
keep agno rbd cod_com_rbd mrun gen_alu fec_nac_alu edad_alu cod_com_alu nom_com_alu
save "$data/matricula_mineduc2020.dta", replace

import delimited "$data\Matricula-por-estudiante-2021\20210913_Matrícula_unica_2021_20210430_WEB.csv", clear
keep agno rbd cod_com_rbd mrun gen_alu fec_nac_alu edad_alu cod_com_alu nom_com_alu
save "$data/matricula_mineduc2021.dta", replace
*/
clear
forvalues z=2004/2021 {
	preserve
	use agno mrun fec_nac_alu gen_alu cod_com_alu using "$data_mineduc\matricula_mineduc`z'", clear
	tostring mrun, replace
	tempfile x
	duplicates tag mrun, gen(aux)
	drop if aux>0
	save `x'
	restore
	append using `x'
	*sort mrun agno
	drop if mrun==" "
	*duplicates drop mrun fec_nac_alu, force // esto tengo que arreglarlo para quedarme con la data más antigua, y su año/mes/dia.
	}
sort mrun agno
egen min=min(agno), by(mrun)
keep if agno==min
drop aux
drop min

tostring fec_nac_alu, replace
gen x=strlen(fec_nac_alu)
gen date=fec_nac_alu if x==8
gen yob=substr(fec_nac_alu,1,4) if x==8
gen mob=substr(fec_nac_alu,5,2) if x==8
gen dob=substr(fec_nac_alu,7,2) if x==8
replace yob=substr(fec_nac_alu,1,4) if x==6
replace mob=substr(fec_nac_alu,5,2) if x==6
drop x

gen birth_daily = daily(fec_nac_alu, "YMD")
format birth_daily %td

forval i = 1/280 {
	gen birth_daily_lag`i' = birth_daily - `i'
	format birth_daily_lag`i' %td
}

save "$data_mineduc/births.dta", replace

*Fixing municipalities code:
use "$data_mineduc\births.dta", clear
rename cod_com_alu Cod_Comuna_2018
tostring Cod_Comuna_2018, replace
gen x=strlen(Cod_Comuna_2018)
gen x2="0"
ereplace Cod_Comuna_2018=concat(x2 Cod_Comuna_2018) if x==4
drop if Cod_Comuna_2018=="0" // 0.72%
merge m:1 Cod_Comuna_2018 using "C:\Users\Pedro\Documents\GitHub\wildfires\data\comunaBase.dta"
gen comuna=Cod_Comuna_2018
replace Cod_Comuna_2018="" if _merge==1
rename _merge merge1
preserve
use "C:\Users\Pedro\Documents\GitHub\wildfires\data\comunaBase.dta", clear
rename Cod_Comuna_2000 comuna
rename Cod_* v2Cod_*
tempfile aux
save `aux'
restore 
merge m:1 comuna using `aux' 
rename _merge merge2 

foreach var in Cod_Comuna_1999  Cod_Comuna_2008 Cod_Comuna_2010 Cod_Comuna_2018 {
    replace `var'=v2`var' if `var'==""
}
replace Cod_Comuna_2000=comuna if Cod_Comuna_2000==""
gen merge=(merge1==3 | merge2==3)
drop x v2* 
drop x2
drop merge*
*Ojo con la comuna 01406, que no le encuentro match
*duplicates drop Cod_Comuna_1999 Cod_Comuna_2000 Cod_Comuna_2008 Cod_Comuna_2010 Cod_Comuna_2018 , force
drop if Cod_Comuna_2018==""
drop comuna
drop Nom_Comuna
preserve
use "C:\Users\Pedro\Documents\GitHub\wildfires\data\comunaBase.dta", clear
keep Cod_Comuna_2018 Nom_Comuna
tempfile aux
save `aux'
restore 
merge m:1 Cod_Comuna_2018 using `aux'
order mrun agno gen_alu fec_nac_alu date yob mob dob Cod_* Nom_Comuna
drop merge
save "$data_mineduc/births_v2.dta", replace

*-------------------------------------------------------------------------------
** (2) SIMCE SCORE + FAMILY VARIABLES (in progress)
*-------------------------------------------------------------------------------
// 4th GRADE MATH & LANGUAGE SIMCE SCORE
forvalues z=2005/2007{
    use "$data_simce\simce4b`z'_alu.dta", clear
	cap rename com natu
	destring leng mate natu, replace dpcomma
	tostring mrun, replace
	keep rbd genero mrun leng mate idalumno	
	gen year=`z'
	save "$data_simce\simce4b`z'.dta", replace
}
forvalues z=2008/2017{
    use "$data_simce\simce4b`z'_alu.dta", clear
	cap rename sexo genero
	cap rename gen_alu genero	
	destring ptje* , replace force dpcomma
	keep rbd genero mrun ptje* idalumno
	tostring mrun, replace
	gen year=`z'
	save "$data_simce\simce4b`z'.dta", replace
}
clear all
forvalues z=2005/2017{
preserve
use "$data_simce\simce4b`z'.dta", clear
if `z'>=2012{
    rename genero sex
	cap decode sex, gen(genero)
	cap tostring sex, replace
	cap rename sex genero
}
tempfile x
save `x'
restore
append using `x'
}
gen female=0 if genero!=""
replace female=1 if genero=="Mujeres" | genero=="2" | genero=="F" | (genero=="M" & year<2010)
replace mate=ptje_mat if mate==.
replace mate=ptje_mate4b_alu if mate==.
replace leng=ptje_lect4b_alu if leng==.
replace leng=ptje_len if leng==.
replace leng=ptje_lect if leng==.
keep rbd mrun year female mate leng idalumno
gen curso="4b"
order rbd mrun idalumno year curso female mate leng
drop if mrun=="."
sort year idalumno
isid year idalumno
save "$data_simce\simce4b.dta", replace

// 4th GRADE FAMILY CHARACTERISTICS
*2005
use "$data_simce\simce4b2005_cpad.dta", clear
rename (preg7 preg8 preg12) (father_educ mother_educ hh_income)
gen year=2005
keep year idalumno father_educ mother_educ hh_income
tempfile pad2005
save `pad2005'
*2006
use "$data_simce\simce4b2006_cpad.dta", clear
rename (preg9 preg10 preg15) (father_educ mother_educ hh_income)
gen year=2006
keep year idalumno father_educ mother_educ hh_income
tempfile pad2006
save `pad2006'
*2007
use "$data_simce\simce4b2007_cpad.dta", clear
rename (p6 p7 p8 /*???*/) (father_educ mother_educ hh_income)
gen year=2007
keep year idalumno father_educ mother_educ hh_income
tempfile pad2007
save `pad2007'
*2008
use "$data_simce\simce4b2008_cpad.dta", clear
local s=5
foreach var in mother_educ father_educ hh_income {
	gen `var'=.
	local i=0
	forvalues z=1/21{
	    local i=`i'+1
		cap replace `var'=`i' if preg0`s'_`i'==1
	}	
local s=`s'+1
}
gen year=2008
keep year idalumno father_educ mother_educ hh_income
tempfile pad2008
save `pad2008'
*2009
use "$data_simce\simce4b2009_cpad.dta", clear
drop p11*
rename (p09p_* p10_* p09m_* ) (p9_* p11_* p10_* )
local s=9
foreach var in mother_educ father_educ hh_income {
	gen `var'=.
	local i=0
	forvalues z=1/21{
	    local i=`i'+1
		cap replace `var'=`i' if p`s'_`i'==1
	}	
local s=`s'+1
}
gen year=2009
keep year idalumno father_educ mother_educ hh_income
tempfile pad2009
save `pad2009'
*2010
use "$data_simce\simce4b2010_cpad.dta", clear
rename (p09* p010*) (p9* p10*)
local s=9
foreach var in mother_educ father_educ hh_income {
	gen `var'=.
	local i=0
	forvalues z=1/21{
	    local i=`i'+1
		cap replace `var'=`i' if p`s'_`i'==1
	}	
local s=`s'+1
}
gen year=2010
keep year idalumno father_educ mother_educ hh_income
tempfile pad2010
save `pad2010'
*2011
use "$data_simce\simce4b2011_cpad.dta", clear
rename (p08* p09*) (p8* p9*)
local s=8
foreach var in mother_educ father_educ hh_income {
	gen `var'=.
	local i=0
	forvalues z=1/21{
	    local i=`i'+1
		cap replace `var'=`i' if p`s'_`i'==1
	}	
local s=`s'+1
}
gen year=2011
keep year idalumno father_educ mother_educ hh_income
tempfile pad2011
save `pad2011'
*2012
use "$data_simce\simce4b2012_cpad.dta", clear
rename (cpad_p08 cpad_p09 cpad_p10) (father_educ mother_educ hh_income)
gen year=2012
keep year idalumno father_educ mother_educ hh_income
tempfile pad2012
save `pad2012'
*2013
use "$data_simce\simce4b2013_cpad.dta", clear
rename (agno cpad_p02 cpad_p07 cpad_p08 cpad_p09) (year parent_age father_educ mother_educ hh_income)
keep year idalumno parent_age father_educ mother_educ hh_income
tempfile pad2013
save `pad2013'

use `pad2005', clear
forvalues z=2006/2013{
    append using `pad`z''
}
save "$data_simce\family_simce4b.dta", replace

// MERGE SCORE - FAMILY 
use "$data_simce\simce4b.dta", clear
merge 1:m year idalumno using "$data_simce\family_simce4b.dta"
keep if _merge!=2

*-------------------------------------------------------------------------------
** (3) WILDFIRES: Daily level + Monthly lags & leads (in progress)
*-------------------------------------------------------------------------------
foreach HA of numlist 0 50 100 150 200 250 500 {
	use  "C:\Users\Pedro\Documents\GitHub\wildfires\data\exposure\exposureDaily_`HA'ha_donut0.dta", clear
	keep Cod_Comuna_2018 date upwind downwind nondownwind fire
	rename (upwind downwind nondownwind fire) (upwind`HA' downwind`HA' nondownwind`HA' fire`HA')
	drop if date>18600
	format date %td
	sort Cod_Comuna_2018 date
	gen year_of_fire=year(date)
	tempfile fire`HA'
	save `fire`HA''
}

use `fire0'	, clear
foreach HA of numlist 50 100 150 200 250 500 {
    merge 1:1 Cod_Comuna_2018 date using `fire`HA''	
	drop _merge
}
save "$data/aux_wildfiresHA", replace

local y=1
local x=30
forvalues s=1/9{
use "$data/aux_wildfiresHA", clear
drop if year>2012
preserve
keep Cod_Comuna_2018 date upwind* downwind* nondownwind*
tempfile fires
save `fires'
restore
forval i = `y'/`x' {
	gen fire_daily_lag`i' = date - `i'
	format fire_daily_lag`i' %td
}
rename date date_base
	local i=`y'
		foreach var of varlist fire_daily_lag`y'-fire_daily_lag`x' {
			di `i'
			rename `var' date
			merge m:1 date Cod_Comuna_2018 using `fires' /*nogen parallel*/
			keep if _merge != 2
*			gen lag_merge_`i' = 1 if _merge == 3
			drop _merge
			drop date
			foreach HA of numlist 0 50 100 150 200 250 500 {
				rename (upwind`HA' downwind`HA' nondownwind`HA') (upwind`HA'_t`i' downwind`HA'_t`i' nondownwind`HA'_t`i')
			}
			local i = `i' + 1
		}
drop fire* year_of_fire
			foreach HA of numlist 0 50 100 150 200 250 500 {
			egen upwind`HA'_month`s'=rowtotal(upwind`HA'_t*)
			egen downwind`HA'_month`s'=rowtotal(downwind`HA'_t*)
			egen nondownwind`HA'_month`s'=rowtotal(nondownwind`HA'_t*)
			}
drop *_t*			
save "$data/month_wildfires`s'", replace
local y=`y'+30
local x=`x'+30
}

use "$data/month_wildfires1", clear
forvalues z=2/9 {
	merge 1:1 date Cod_Comuna_2018 using "$data/month_wildfires`z'"
	drop _merge
}
save "$data/month_wildfires.dta", replace

*-------------------------------------------------------------------------------
** (4) Put all data together
*-------------------------------------------------------------------------------

use "$data_mineduc\births_v2.dta", clear
drop birth_daily*
merge 1:m mrun using "$data_simce\simce4b.dta"
keep if _merge==3
drop _merge
destring yob date, replace
keep if yob>=2003 & yob<=2008
gen date_base = daily(fec_nac_alu, "YMD")
format date_base %td

merge m:1 Cod_Comuna_2018 date_base using "$data/month_wildfires.dta"
keep if _merge==3
drop _merge

mean mate
local mean = _b[mate]
tempvar sd
egen `sd'=sd(mate)
gen mate_std=(mate-`mean')/`sd'
mean leng
local mean = _b[leng]
tempvar sd
egen `sd'=sd(leng)
gen leng_std=(leng-`mean')/`sd'
cap egen pop=count(mrun), by(Cod_Comuna_2018 yob)

foreach HA of numlist 0 50 100 150 200 250 500 {
gen trimestreUP`HA'_lag1=(upwind`HA'_month1 + upwind`HA'_month2 + upwind`HA'_month3)
gen trimestreDOWN`HA'_lag1=(downwind`HA'_month1 + downwind`HA'_month2 + downwind`HA'_month3)
gen trimestreUP`HA'_lag2=(upwind`HA'_month4 + upwind`HA'_month5 + upwind`HA'_month6)
gen trimestreDOWN`HA'_lag2=(downwind`HA'_month4 + downwind`HA'_month5 + downwind`HA'_month6)
gen trimestreUP`HA'_lag3=(upwind`HA'_month7 + upwind`HA'_month8 + upwind`HA'_month9)
gen trimestreDOWN`HA'_lag3=(downwind`HA'_month7 + downwind`HA'_month8 + downwind`HA'_month9)
}

label var mrun "Student ID"
label var agno "Year of annual school tuition"
label var year "Year of test score"
label var yob "Year of birth"
label var mob "Month of birth"
label var dob "Day of birth"
label var gen_alu "Student sex"
label var fec_nac_alu "Date of birth"
label var date "Date of birth"
label var date_base "Date of birth"
label var curso "Grade"
label var mate "Math score"
label var leng "Language score"
label var mate_std "Standardized Math Score"
label var leng_std "Standardized Language Score"
label var pop "Municipality-Year of birth-Students population"

save "$data/analysisEduc.dta", replace
