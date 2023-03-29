# makeMaps.py                    damiancclarke             yyyy-mm-dd:2022-12-01
#---|----1----|----2----|----3----|----4----|----5----|----6----|----7----|----8
#
#   This file makes maps documenting wind bearings crossed with fire intensities
# and combines these maps into gifs.  This can all be controlled using different
# month spans and time periods in section 3 where functions are called.  This is
# run using Python 3.8.10, but should work with any version of Python 3 provided
# dependencies are installed.
#
# To run this code, the location of materials on the users machine should be set
# on line 36.

################################################################################
### [0] Imports
################################################################################
import numpy as np
import pandas as pd

import shapefile as shp
import matplotlib.pyplot as plt
import seaborn as sns
import geopandas as gpd
import matplotlib.lines as mlines
import pyreadr

from PIL import Image
import glob
from datetime import date, timedelta

import matplotlib.colors as colors
from matplotlib.patches import Patch

sns.set(style="whitegrid", palette="pastel", color_codes=True)
sns.mpl.rc("figure", figsize=(10,6))

base = "/home/damian/investigacion/2022/climateChangeLatAm/replication"


################################################################################
### [1] Generate main mapping script
################################################################################
def makemap(fireP,windP,shpP,fname,date,lat=None,lon=None,delta=30,distance=None):
    """
    makemap takes files of wind paths and fires, and generates a map.

    :param fireP: location where file of fires is
    :param windP: location where file of wind directions is
    :param fname: file name to save map
    :param lat: optional latitude restriction entered as [123,456]
    :param long: optional longitude restriction entered as [123,456]

    """
    
    wind = pd.read_stata(windP)
    wind = wind.loc[wind['Date']==date]
    wind.Long       = wind['Long'].astype('float64')
    wind.Lat        = wind['Lat'].astype('float64')
    wind.viento_u10 = wind['viento_u10'].astype('float64')
    wind.viento_v10 = wind['viento_v10'].astype('float64')
    wind.CUT_2018   = wind['CUT_2018'].astype('int64')
    

    fire = pd.read_stata(fireP)
    fire = fire.loc[fire['Date']==date]
    fire.CUT_2018 = fire['CUT_2018'].astype('int64')

    gdf  = gpd.GeoDataFrame(fire, geometry=gpd.points_from_xy(fire.lo1, fire.la1))

    ###THIS HAS COMUNAS WITH COMUNA ANGLE FROM RUBI
    both = pd.merge(fire,wind,on="CUT_2018", how="left")

    both['windangle']= np.arctan2(both.viento_u10,both.viento_v10)*180/np.pi
    both.windangle=np.where(both.windangle<0,both.windangle+360,both.windangle)
    both['windP']=both.windangle+delta
    both.windP=np.where(both.windP<0,both.windP+360,both.windP)
    both['windM']=both.windangle-delta
    both.windM=np.where(both.windM<0,both.windM+360,both.windM)

    both['c1'] = both.beta_grado.between(both.windM,both.windP)
    both['c2a'] = both.beta_grado.between(0,both.windP)
    both['c2b'] = both.beta_grado.between(both.windM,360)
    both['c2']  = both.c2a+both.c2b
    both['c3a'] = both.windangle>(360-delta)
    both['c3b'] = both.windangle<delta
    both['c3']  = both.c3a+both.c3b
    both['Upwind'] = both.c1*(1-both.c3)+both.c2*both.c3
    #both['Upwind'] = (both.c1==True and both.c3==False) or (both.c2==True and both.c3==True)

    upwind = both[['Distancia','Upwind','CUT_2018']].groupby('CUT_2018').mean()
    #distance = both[[,'CUT_2018']].groupby('CUT_2018').mean()

    
    ###CHECK IF COMUNAS WITHIN delta DEGREES OF WINDANGLE
    sf = gpd.read_file(shpP)
    sf = sf.to_crs('epsg:4326')
    sf['CUT_2018']=sf.cod_comuna
    sf = pd.merge(sf,upwind,on="CUT_2018",how="left")
    sf['cvar'] = np.where(sf.Upwind>0,1,sf.Upwind)
    if distance!=None:
        sf['cvar']=sf.Distancia

    fig, ax = plt.subplots(figsize=(10, 10))

    #sf.plot(ax=ax, column='Distancia',cmap="viridis",
    #color_dict = {'0':'#440154', '1':'#fde725'}
        
    #sf.plot(ax=ax, column='cvar',cmap=colors.ListedColormap(list(color_dict.values())),
    if distance==None:
        lng = False
        valmn = 0
        valmx = 1
    else:
        lng = True
        valmn = 0
        valmx = 120000
        
    sf.plot(ax=ax,column='cvar',cmap="viridis",vmin=valmn, vmax=valmx,
            missing_kwds={
                "color": "lightgrey",
                "edgecolor": "grey",
                "label": "Missing values",
            },
            legend=lng,
            alpha=0.7)

    #only for wind
    if distance==None:
        legend_elements = [Patch(facecolor='#440154',edgecolor='grey',label='downwind',alpha=0.7),
                           Patch(facecolor='#fde725',edgecolor='grey',label='upwind',alpha=0.7)]
        ax.add_artist(ax.legend(handles=legend_elements,loc=2))

    if lat!=None:
        ax.set_xlim(lat[0],lat[1])
    if lon!=None:
        ax.set_ylim(lon[0],lon[1])

    fire.Superficie=np.where(fire.Superficie<=0,0.01,fire.Superficie)        
    scale = 2
    f = gdf.plot(ax=ax, color='orange', edgecolor='black',
                 alpha=0.1,markersize=(fire.Superficie**0.9)*scale)    
    ax.set_title(date)

    
    plt.quiver(wind.Long,wind.Lat,wind.viento_u10,wind.viento_v10,
               alpha=0.6, width=0.006)

    try:
        _, bins = pd.cut(fire.Superficie, bins=5, precision=0, retbins=True)
        # create second legend
        ax.add_artist(
            ax.legend(
                handles=[
                    mlines.Line2D(
                        [],
                        [],
                        color="orange",
                        lw=0,
                        marker="o",
                        markersize=np.sqrt(b),
                        label=str(int(b)),
                    )
                    for i, b in enumerate(bins)
                ],
                loc=4,title="Area burned"
            )
        )
    except:
        print(date + " no fires found")
    plt.savefig(fname,bbox_inches='tight')
    plt.close('all')

#for create a vector of dates
def get_start_to_end(start_date, end_date):
    date_list = []
    for i in range(0, (end_date - start_date).days + 1):
        date_list.append(  str(start_date + timedelta(days=i)) )
    return date_list


# create gifs
def makemapgif(pngP,gname,yearB,monthB,dayB,yearE,monthE,dayE,distance=None):
    """
    makemapgif takes png files and generates a map.

    :param pngP: location where png files are
    :param gname: file name to save gif
    :param yearB: Begin
    :param monthB: Begin
    :param dayB: Begin
    :param yearE: End
    :param monthE: End
    :param dayE: End
        
    """
    if distance==None:
        name = 'upwind' 
    else:
        name = 'distance'
            
    sd = date(yearB,monthB,dayB)
    ed = date(yearE,monthE,dayE)
    dates = get_start_to_end(sd, ed)
    rows = len(dates)
    
    for i in range (0,rows):
        dates[i] = dates[i].replace("-","_")
    
    imgs = []
    for i in range (0,rows):
        newpatha = pngP+name+'_'+dates[i]+'_a.png'
        newpathb = pngP+name+'_'+dates[i]+'_b.png'
        newpathc = pngP+name+'_'+dates[i]+'_c.png'
        newpathd = pngP+name+'_'+dates[i]+'_d.png'
        newpathe = pngP+name+'_'+dates[i]+'_e.png'
        newpathf = pngP+name+'_'+dates[i]+'_f.png'
        newpathg = pngP+name+'_'+dates[i]+'_g.png'
        newpathh = pngP+name+'_'+dates[i]+'_h.png'

        imgs.append(newpatha)
        imgs.append(newpathb)
        imgs.append(newpathc)
        imgs.append(newpathd)
        imgs.append(newpathe)
        imgs.append(newpathf)
        imgs.append(newpathg)
        imgs.append(newpathh)
        
    frames = []
    for i in imgs:
        new_frame = Image.open(i)
        frames.append(new_frame)
        
    fn_save = pngP+'gifs/'+gname+'.gif'
    frames[0].save(fn_save, format='GIF', append_images=frames[1:],
                   save_all=True, duration=300, loop=0)
    

################################################################################
### [3] Make maps
################################################################################
year = 2019
shps  = base+"data/maps/comunas.shp"
winds = base+"data/wind/u10_v10_"+str(year)+".dta"
fires = base+"data/maps/fires"+str(year)+".dta"
res   = base+'results/maps/'

for month in range (9,12):
    if month==9 or month==11:
        mday = 31
    else:
        mday = 32
    for day in range(1,mday):
        sday  = str(day).zfill(2)
        smon  = str(month).zfill(2)
        syear = str(year)
        
        dlim = syear+'-'+smon+'-'+sday
        print(dlim)
        
        fn = res+'upwind_'+syear+'_'+smon+'_'+sday
        la = lat=[-76,-68]
        lo = lon=[-44,-32]
        makemap(fires,winds,shps,fn+'_a.png',dlim+' 00:00:00',la,lo)
        makemap(fires,winds,shps,fn+'_b.png',dlim+' 03:00:00',la,lo)
        makemap(fires,winds,shps,fn+'_c.png',dlim+' 06:00:00',la,lo)
        makemap(fires,winds,shps,fn+'_d.png',dlim+' 09:00:00',la,lo)
        makemap(fires,winds,shps,fn+'_e.png',dlim+' 12:00:00',la,lo)
        makemap(fires,winds,shps,fn+'_f.png',dlim+' 15:00:00',la,lo)
        makemap(fires,winds,shps,fn+'_g.png',dlim+' 18:00:00',la,lo)
        makemap(fires,winds,shps,fn+'_h.png',dlim+' 21:00:00',la,lo)
        
        
        fn = res+'distance_'+syear+'_'+smon+'_'+sday
        makemap(fires,winds,shps,fn+'_a.png',dlim+' 00:00:00',la,lo,distance=1)
        makemap(fires,winds,shps,fn+'_b.png',dlim+' 03:00:00',la,lo,distance=1)
        makemap(fires,winds,shps,fn+'_c.png',dlim+' 06:00:00',la,lo,distance=1)
        makemap(fires,winds,shps,fn+'_d.png',dlim+' 09:00:00',la,lo,distance=1)
        makemap(fires,winds,shps,fn+'_e.png',dlim+' 12:00:00',la,lo,distance=1)
        makemap(fires,winds,shps,fn+'_f.png',dlim+' 15:00:00',la,lo,distance=1)
        makemap(fires,winds,shps,fn+'_g.png',dlim+' 18:00:00',la,lo,distance=1)
        makemap(fires,winds,shps,fn+'_h.png',dlim+' 21:00:00',la,lo,distance=1)


# make gif
png_path = base+'results/maps/'

makemapgif(png_path,'testupwind'  ,2019,9,1,2019,9,9)
makemapgif(png_path,'testdistance',2019,9,1,2019,9,2,distance=1)






#RM lat=[-72,-69.5],lon=[-35,-33]


#ax.set_ylim(-60, -15)
#MIDDLE ZONE
#ax.set_ylim(-45, -30)
#ax.set_xlim(-76, -68)
#RM
#ax.set_ylim(-35, -33)
#ax.set_xlim(-72, -69.5)
    


#ax.set_ylim(-38, -36)
#ax.set_xlim(-74, -69.5)
