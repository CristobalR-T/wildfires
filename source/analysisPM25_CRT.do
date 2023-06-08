


vers 14
clear all
set more off
cap log close


*-------------------------------------------------------------------------------
*--- (0) Globals and locals
*-------------------------------------------------------------------------------
*global ROOT "~/investigacion/2022/climateChangeLatAm/replication"
global ROOT "C:\Users\crist\Documents\GitHub\wildfires\"

global DAT "${ROOT}\data"
global OUT "${ROOT}\results"
global LOG "${ROOT}\log"

log using "$LOG/analysisMP25.txt", text replace
cap mkdir "$OUT/figures"

*-------------
*--- (1) Generating a comuna-by-day panel for PM25 
*-------------------------------------------------------------------------------
cd "$DAT\PM25\"     
local files
foreach yr of numlist 2003(1)2021 {
	display "year is `yr'"
	unzipfile "Municipio_pm2p5_`yr'.zip", replace
    use "$DAT/PM25/Municipio_pm2p5_`yr'.dta", clear
    split Date
	gen date = date(Date1, "YMD")
	format date %td
		decode CUT_2018, gen(Cod_Comuna_2018)
		destring Cod_Comuna_2018, replace
		decode Comuna, gen (Nom_Comuna_pm)
    collapse pm2p5 Cod_Comuna_2018, by(date Nom_Comuna_pm)
    *tostring Cod_Comuna_2018, replace
	keep date pm2p5 Cod_Comuna_2018 Nom_Comuna_pm
	tempfile yr`yr'
    save `yr`yr''
    local files `files' `yr`yr''
	capture erase "$DAT/PM25/Municipio_pm2p5_`yr'.dta"
}
clear
append using `files'
capture drop PM25
gen PM25=pm2p5*1000000000 // PM2.5 in micrograms (as opposed to Kg)
sort date Cod_Comuna_2018
save "$DAT/PM25/PM25_comunaDay.dta", replace
*tempfile PM25_comunaDay
*save `PM25_comunaDay'

*--------
*--- (2) Match exposureDaily with MP 2.5
*-------------------------------------------------------------------------------

cd "$DAT/exposure/" 
local donut 50
	
unzipfile "exposureDaily_25ha_donut`donut'.zip", replace
use "exposureDaily_25ha_donut`donut'.dta", clear

foreach var of varlist upwind downwind nondownwind upwindDistance downwindDistance nondownwindDistance  fire {
	qui replace `var'=0 if `var'==.

rename `var' `var'_25 	
}
	capture drop _merge
	tempfile exposureDaily
	save `exposureDaily'

	capture drop week_date
	gen week_date=wofd(date)
	collapse windSpeed upwindDistance_25 downwindDistance_25 nondownwindDistance_25 (sum) upwind_25 downwind_25 nondownwind_25 fire_25, by (week_date Cod_Comuna_2018)
	tempfile exposureWeekly
	save `exposureWeekly'
	
   foreach size of numlist 50(25)200 250 500 {
	unzipfile "exposureDaily_`size'ha_donut`donut'.zip", replace
	use "exposureDaily_`size'ha_donut`donut'.dta", clear
		foreach var of varlist upwind downwind nondownwind fire upwindDistance downwindDistance nondownwindDistance {
	qui replace `var'=0 if `var'==.
	rename `var' `var'_`size' 	
}
	drop F_exposure_0_45 F_exposure_45_90 F_exposure_90_135 F_exposure_135_180
	tempfile exposureDaily_`size'
	save `exposureDaily_`size''
	
	capture drop week_date
	gen week_date=wofd(date)
	collapse windSpeed upwindDistance_`size' downwindDistance_`size' nondownwindDistance_`size' (sum) upwind_`size' downwind_`size' nondownwind_`size' fire_`size', by (week_date Cod_Comuna_2018)
	tempfile exposureWeekly_`size'
	save `exposureWeekly_`size''

	use `exposureDaily' , clear
	merge 1:1 date Cod_Comuna_2018 using `exposureDaily_`size'',  keepusing(upwind* downwind* nondownwind* upwindDistance* downwindDistance* nondownwindDistance* fire*) 
	capture drop _merge	
	save `exposureDaily', replace
	capture erase "exposureDaily_`size'ha_donut`donut'.dta"

	use `exposureWeekly' , clear
	merge 1:1 week_date Cod_Comuna_2018 using `exposureWeekly_`size'',  keepusing(upwind* downwind* nondownwind* upwindDistance* downwindDistance* nondownwindDistance* fire*) 
	capture drop _merge	
	save `exposureWeekly', replace
	} // end foreach `size'
	capture erase "exposureDaily_25ha_donut`donut'.dta"
	
	destring Cod_Comuna_2018, replace
	sort week_date Cod_Comuna_2018
	save "exposureWeekly.dta", replace

	use `exposureDaily' , clear
   	destring Cod_Comuna_2018, replace
	sort date Cod_Comuna_2018
	// Merging with PM dataset
	merge 1:1 date Cod_Comuna_2018 using "$DAT/PM25/PM25_comunaDay.dta"

	save "expDailyPM.dta", replace
	
*** (3) Regressing PM25 on Upwind Downwind and NonDownwind

xtset Cod_Comuna_2018 date

capture drop LB_up UB_up Beta_up LB_down UB_down Beta_down size equality
gen LB_up     = .
gen UB_up     = .
gen Beta_up   = .
gen LB_down   = .
gen UB_down   = .
gen Beta_down = .
gen size  = .
gen equality  = .

local j=1
foreach size of numlist 25(25)200 250 500 {
	reghdfe PM25 upwind_`size' downwind_`size' nondownwind_`size' , absorb(date Cod_Comuna_2018) cluster(Cod_Comuna_2018)	
	*reghdfe PM25 upwind_`size' downwind_`size' fire_`size' , absorb(date Cod_Comuna_2018) cluster(Cod_Comuna_2018)	

	qui replace Beta_up = _b[upwind_`size'] in `j'
    qui replace LB_up   = _b[upwind_`size']+invnormal(0.025)*_se[upwind_`size'] in `j'
    qui replace UB_up   = _b[upwind_`size']+invnormal(0.975)*_se[upwind_`size'] in `j'

    qui replace Beta_down = _b[downwind_`size'] in `j'
    qui replace LB_down   = _b[downwind_`size']+invnormal(0.025)*_se[downwind_`size'] in `j'
    qui replace UB_down   = _b[downwind_`size']+invnormal(0.975)*_se[downwind_`size'] in `j'
    test upwind_`size'= downwind_`size'
    qui replace equality = r(p) in `j'

    qui replace size = `size' in `j'
    local ++j
	
/* capture drop upwind_`size'_l1 downwind_`size'_l1 fire_`size'_l1
qui gen  upwind_`size'_l1=l1.upwind_`size'
qui gen  downwind_`size'_l1=l1.downwind_`size'
qui gen  fire_`size'_l1=l1.fire_`size'

reghdfe PM25 upwind_`size' upwind_`size'_l1 downwind_`size' downwind_`size'_l1 fire_`size' fire_`size'_l1 , absorb(date Cod_Comuna_2018) cluster(Cod_Comuna_2018)	*/
}

#delimit ;
twoway rarea LB_up UB_up size, color(gs10%30)
   || line Beta_up size, lcolor(red) lwidth(medthick) lpattern(solid)
   || rarea LB_down UB_down size, color(gs10%30)
   || line Beta_down size, lcolor(blue) lwidth(medthick) lpattern(dash)
ytitle("MP 2.5 (kg/m{sup:3})") xtitle("Fire Size (Ha)")
legend(order(2 "Estimate (upwind)" 4 "Estimate (downwind)" 1 "95% CI")
       position(6) rows(1)) yline(0, lpattern(dash));
#delimit cr


** Week-level analysis
	use "$DAT/PM25/PM25_comunaDay.dta", clear
	capture drop week_date
	gen week_date=wofd(date)

	collapse PM25, by (week_date Cod_Comuna_2018)
	sort week_date Cod_Comuna_2018
	
	merge 1:1 week_date Cod_Comuna_201 using "exposureWeekly.dta"
	xtset Cod_Comuna_2018 week_date

local j=1
foreach size of numlist 25(25)200 250 500 {
	reghdfe PM25 upwind_`size' downwind_`size' nondownwind_`size'  , absorb(week_date Cod_Comuna_2018) cluster(Cod_Comuna_2018)	
	
		qui replace Beta_up = _b[upwind_`size'] in `j'
    qui replace LB_up   = _b[upwind_`size']+invnormal(0.025)*_se[upwind_`size'] in `j'
    qui replace UB_up   = _b[upwind_`size']+invnormal(0.975)*_se[upwind_`size'] in `j'

    qui replace Beta_down = _b[downwind_`size'] in `j'
    qui replace LB_down   = _b[downwind_`size']+invnormal(0.025)*_se[downwind_`size'] in `j'
    qui replace UB_down   = _b[downwind_`size']+invnormal(0.975)*_se[downwind_`size'] in `j'
    test upwind_`size'= downwind_`size'
    qui replace equality = r(p) in `j'

    qui replace size = `size' in `j'
    local ++j
}

#delimit ;
twoway rarea LB_up UB_up size, color(gs10%30)
   || line Beta_up size, lcolor(red) lwidth(medthick) lpattern(solid)
   || rarea LB_down UB_down size, color(gs10%30)
   || line Beta_down size, lcolor(blue) lwidth(medthick) lpattern(dash)
ytitle("MP 2.5 (kg/m{sup:3})") xtitle("Fire Size (Ha)")
legend(order(2 "Estimate (upwind)" 4 "Estimate (downwind)" 1 "95% CI")
       position(6) rows(1)) yline(0, lpattern(dash));
#delimit cr





	** 3.1 Generating variables MostlyUpwind MostlyDownwind and MostlyNonDownwind
foreach size of numlist 25(25)200 250 500 {
	capture drop Mostly_upwind_`size' Mostly_downwind_`size'
	qui gen Mostly_upwind_`size'=upwind_`size' if (upwind_`size'>downwind_`size') | (upwind_`size'==downwind_`size')
	qui replace Mostly_upwind_`size'=0 if upwind_`size'<downwind_`size' 
	qui gen Mostly_downwind_`size'=downwind_`size' if (downwind_`size'>upwind_`size') | (downwind_`size'==upwind_`size')
	qui replace Mostly_downwind_`size'=0 if downwind_`size'<upwind_`size'  
	}

	capture drop LB_up UB_up Beta_up LB_down UB_down Beta_down size equality
gen LB_up     = .
gen UB_up     = .
gen Beta_up   = .
gen LB_down   = .
gen UB_down   = .
gen Beta_down = .
gen size  = .
gen equality  = .

local j=1
foreach size of numlist 25(25)200 250 500 {
	reghdfe PM25 Mostly_upwind_`size' Mostly_downwind_`size' nondownwind_`size' , absorb(date Cod_Comuna_2018) cluster(Cod_Comuna_2018)	

	qui replace Beta_up = _b[Mostly_upwind_`size'] in `j'
    qui replace LB_up   = _b[Mostly_upwind_`size']+invnormal(0.025)*_se[Mostly_upwind_`size'] in `j'
    qui replace UB_up   = _b[Mostly_upwind_`size']+invnormal(0.975)*_se[Mostly_upwind_`size'] in `j'

    qui replace Beta_down = _b[Mostly_downwind_`size'] in `j'
    qui replace LB_down   = _b[Mostly_downwind_`size']+invnormal(0.025)*_se[Mostly_downwind_`size'] in `j'
    qui replace UB_down   = _b[Mostly_downwind_`size']+invnormal(0.975)*_se[Mostly_downwind_`size'] in `j'
    test Mostly_upwind_`size'= Mostly_downwind_`size'
    qui replace equality = r(p) in `j'
    qui replace size = `size' in `j'
    local ++j
}

#delimit ;
twoway rarea LB_up UB_up size, color(gs10%30)
   || line Beta_up size, lcolor(red) lwidth(medthick) lpattern(solid)
   || rarea LB_down UB_down size, color(gs10%30)
   || line Beta_down size, lcolor(blue) lwidth(medthick) lpattern(dash)
ytitle("MP 2.5 (kg/m{sup:3})") xtitle("Fire Size (Ha)")
legend(order(2 "Estimate (M-upwind)" 4 "Estimate (M-downwind)" 1 "95% CI")
       position(6) rows(1)) yline(0, lpattern(dash));
#delimit cr



	
	reghdfe PM25 Mostly_upwind_25 Mostly_downwind_25 fire_25 , absorb(date Cod_Comuna_2018) cluster(Cod_Comuna_2018)
	reghdfe PM25 Mostly_upwind_50 Mostly_downwind_50 fire_50 , absorb(date Cod_Comuna_2018) cluster(Cod_Comuna_2018)	
	reghdfe PM25 Mostly_upwind_100 Mostly_downwind_100 fire_100, absorb(date Cod_Comuna_2018) cluster(Cod_Comuna_2018)
	reghdfe PM25 Mostly_upwind_200 Mostly_downwind_200 fire_200, absorb(date Cod_Comuna_2018) cluster(Cod_Comuna_2018)
	reghdfe PM25 Mostly_upwind_500 Mostly_downwind_500 fire_500, absorb(date Cod_Comuna_2018) cluster(Cod_Comuna_2018)
