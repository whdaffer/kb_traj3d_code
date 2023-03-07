
;;--------------------------------------
;;
;; check Dessler/Tao's input files.
files=file_search('~/processing/trajectory/*.nc')

fid = ncdf_open(files[0])
id = ncdf_varid(fid,'u')
ncdf_varget,fid,id,u
id = ncdf_varid(fid,'Seconds')
ncdf_varget,fid,id,seconds
id = ncdf_varid(fid,'Time')
ncdf_varget,fid,id,time
id = ncdf_varid(fid,'Julian_day')
ncdf_varget,fid,id,jd
ncdf_close,fid


fid = ncdf_open(files[1])
id = ncdf_varid(fid,'u')
u = 0 &  ncdf_varget,fid,id,u
id = ncdf_varid(fid,'Seconds')
ncdf_varget,fid,id,seconds
id = ncdf_varid(fid,'Time')
ncdf_varget,fid,id,time
id = ncdf_varid(fid,'Julian_day')
ncdf_varget,fid,id,jd
ncdf_close,fid

xx = where(jd,nxx)
help,u,jd,nxx



