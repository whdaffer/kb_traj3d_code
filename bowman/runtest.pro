
datei = (datef = {jtime})
datei.jday = julday(2,2,2009)
datei.seconds = 0l
datef.jday = julday(2,27,2009)
datef.seconds = 0l

infile = "~whdaffer/processing/traj3d/MERRA_UVQ_isen_6hrly_200902.nc"
restartFile = 'MLSLocations_20090201.nc'
traj3d,infile,datei,datef,86400.0/(30*60.0),4,4,/debug,restart=restartFile

