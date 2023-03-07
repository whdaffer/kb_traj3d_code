;+
;
; @param
; @keyword help {in}{type=boolean}{default=false}
;    Print a usage message and exit
; @keyword verbose {in}{type=boolean}{default=false}
;    Increase the number of messages emitted (not implemented as yet)
; @keyword nocatch {in}{type=boolean}{default=false}
;   bypass catch blocks
; @returns
; @examples
;
;-

PRO make_mls_file, date, $
                   version=version, $
                   clobber=clobber, $
                   help=help,$
                   verbose=verbose,$
                   nocatch=nocatch


  COMPILE_OPT IDL2, LOGICAL_PREDICATE
  rcsid="$Id$"
  t0 = systime(1)
  Message,'Starting at ' + systime(),/info
  user=getenv('USER')
  hostname=getenv('HOSTNAME')
  IF hostname eq '' THEN BEGIN 
    spawn,'hostname',hostname
  ENDIF 
  Message,'I am ' + user + ' running on ' + hostname,/info


  RunTime_Parameter_Handler, status
  IF status EQ 0 THEN BEGIN 
    print,'RunTime_Parameter_Handler returned 0 -- Aborting'
    return
  ENDIF 

  IF keyword_set(nocatch) EQ 0 THEN BEGIN 
    catch, error
    IF error NE 0 THEN BEGIN 
      catch,/cancel
      Message,!error_state.msg,/cont
      et = strtrim(systime(1)-t0,2)
      IF n_elements(fid) NE 0 THEN ncdf_close,fid
      Message,'Failure! Elapsed time : ' + et + ' seconds ',/info
      return
    ENDIF 
  ENDIF 
  
  help = keyword_set(help)
  IF help THEN BEGIN 
    Message,usage,/info
    return;;,0
  ENDIF 
  verbose=n_elements(verbose) ne 0 ? verbose : 0

  ;; CD to the working directory, if need be
  cd,cur=cur
  MESSAGE,'Starting in ' + cur[0],/info
  IF N_ELEMENTS(workdir) NE 0 && $
   SIZE(workdir,/TNAME) EQ 'STRING' THEN BEGIN 
    Message,'CD-ing to ' + workdir[0] + " hope that's ok!",/info
    CD,workdir
  ENDIF 
  cd,cur=cur
  MESSAGE,'Now in ' + cur[0],/info

  ;; Generate the report on the runtime executable, if this is an
  ;; instance of runtime job
  idents = (rtsave_rpt = 'Not in Runtime ENV: information is not available')
  RTSAVE_REPORT,isRunTime=isRunTime,$
                output=rtsave_rpt, $
                idents=idents, $
                verbose=verbose 

  IF isRunTime THEN BEGIN 
    Message,"***** Information on the RunTime saveset",/info
    print,rtsave_rpt
    Message,'***** Done with RunTime Saveset report',/info
  ENDIF 

  ;; Read any rtDat files that may have been passed in.
  rtdatfile_rpt = 'No rtdatfile'
  IF n_elements(rtdatfile)  NE 0 && $
   size(rtdatfile,/tname) EQ 'STRING' THEN BEGIN 
    status = EXECUTE_RTDatFile(rtdatfile[0],$
                               report=rtdatfile_rpt, $
                               verbose=verbose, $
                              nocatch=nocatch)
    IF status EQ 0 THEN $
     Message,'execute_rtdatfile(' + rtdatfile[0] + ') failed!'
  ENDIF 

  ;; ============ begin main processing ==============

  dt = whd_datetime(unknown=date)
  auraday = dt.auraday
  datestring = string(dt.date,'(i8)')

  IF n_elements(VERSION) EQ 0 THEN version = getMLSDefaultVersion()
  dggfile = locateEMLSDaySeries(auraday,$
                               product="Temperature-InitPtan",$
                               version=version, $
                               order=['version desc','cycle desc'])
  temp = readL2GPFile(dggfile[0],swath="Temperature-InitPtan")

  fNan = !values.f_nan
  noSurfs = temp.noSurfs
  noProfs = temp.noProfs
  dud = temp.baddata 

  mlsLats = transpose(rebin(temp.lat,noProfs,noSurfs))
  mlsLons = transpose(rebin(temp.lon,noProfs,noSurfs))
  ;; Transposing put the pressure dimension first
  mlsTemp = transpose(temp.val)
  mlsPress = rebin(temp.Surfs,noSurfs,noProfs)

  jd = transpose(rebin(temp.Day,noProfs,noSurfs))
  time = temp.time &  time /=  1000.0
  time = transpose(rebin(time,noProfs,noSurfs))
  temp = 0

  good = where(abs(mlsTEMP-dud) GT 1 AND $
               abs(mlsPress-dud) GT 1,ngood,$
               comp=bad,ncomp=nbad)
  IF nbad NE 0 THEN mlsTEMP[bad] = fnan

  mlsTheta = mlsTemp*(1000/mlsPress)^(2./7.)

  maxTheta = 5000
  minTheta = 200
  xx = where(finite(mlsTheta) AND $
             (mlsTheta GE minTheta AND $
             mlsTheta LE maxTheta), nxx, $
             comp = bad,ncomp=nbad)
  IF nbad NE 0 THEN BEGIN 
    mlsTheta = mlsTheta[xx]
    mlsLats = mlsLats[xx]
    mlsLons = mlsLons[xx]
    JD = JD[xx]
    time = time[xx]
  ENDIF 
  
  ;; sort by date/time
  dt1 = whd_datetime(julday=jd,time=time)
  ss = dt1.sort()
  mlsLats = mlsLats[ss]
  mlsLons = mlsLons[ss]
  mlsTheta = mlsTheta[ss]
  jd = long(dt1.julday)
  time = dt1.time
  dt1 = !null

  fnan = !values.f_nan
  nProfs = n_elements(mlsTheta) 
  outFile = string(dt.date,'(%"MLSLocations_%8d.nc")')
  fid = ncdf_create(outFile,clobber=clobber)
  ParticleDimID = ncdf_dimdef(fid,'Particle',nProfs)
  
  ts_per_day_id = ncdf_vardef(fid,'Number_of_timesteps_per_day',/long)
  num_saves_per_day_id = ncdf_vardef(fid,'Number_of_saves_per_day',/long)
  numPlotsPerDayID = ncdf_vardef(fid,'Number_of_plots_per_day',/long)

  jdID = ncdf_vardef(fid,'Julian_day',[ParticleDimID],/long)
  ncdf_attput,fid,jdID,'_FillValue',-1l
  ncdf_attput,fid,jdID,'units',"day",/char

  secsID = ncdf_vardef(fid,'Seconds', [ParticleDimID], /float)
  ncdf_attput,fid,secsID,'_FillValue',fnan
  ncdf_attput,fid,secsID,'units','Time of day in seconds',/char

  lonID = ncdf_vardef(fid,'Longitude',[ParticleDimID],/float)
  ncdf_attput,fid,lonID,'_FillValue',fnan
  ncdf_attput,fid,lonid,'units',"degrees",/char

  latID = ncdf_vardef(fid,'Latitude', [ParticleDimID],/float)
  ncdf_attput,fid,latID,'_FillValue',fnan
  ncdf_attput,fid,latid,'units',"degrees",/char

  altID = ncdf_vardef(fid,'Altitude', [ParticleDimID],/float)
  ncdf_attput,fid,altID,'units',"K",/char
  ncdf_attput,fid,altID,'_FillValue',fnan

  seedID = ncdf_vardef(fid,'seed', /long)
  
  ncdf_control,fid,/endef ;; stop defining
  
  ;; Now fill the files

  ts_per_day = 86400/(60*30.0) ;; time steps every 30 minutes
  num_saves_per_day = ts_per_day
  numPlotsPerDay = 24 ; once per hour

  ncdf_varput,fid,ts_per_day_id,ts_per_day
  ncdf_varput,fid,num_saves_per_day_id,num_saves_per_day
  ncdf_varput,fid,numPlotsPerDayID,numPlotsPerDay
  ncdf_varput,fid,jdid, jd
  ncdf_varput,fid,secsID, time
  ncdf_varput,fid,lonid, mlsLons
  ncdf_varput,fid,latid, mlsLats
  ncdf_varput,fid,altID, mlstheta

  seed = ulong( randomn(s,1)*1000 )
  ncdf_varput,fid,seedID,seed
  
  ncdf_close,fid &  fid = !null
  


  ;; ============ end  main processing ==============

  et=long(systime(1)-t0)
  elapsed_time=string(et,'(%"Elapsed time: %d seconds")')
  Message,/info,elapsed_time
  Message,/info,'Success! Done at ' + systime()

END 
;
; $Id$
;
; Modification Log
; $Log$
;
; 
; Copyright 2012, by the California Institute of
; Technology. ALL RIGHTS RESERVED. United States Government
; Sponsorship acknowledged. Any commercial use must be
; negotiated with the Office of Technology Transfer at the
; California Institute of Technology. 
; 
; This software may be subject to U.S. export control
; laws. By accepting this software, the user agrees to
; comply with all applicable U.S. export laws and
; regulations. User has the responsibility to obtain export
; licenses, or other export authority as may be required
; before exporting such information to foreign countries or
; providing access to foreign persons. 
; 
; Last Modified : Tue  9 Oct 2012 14:13:58 PM PDT
