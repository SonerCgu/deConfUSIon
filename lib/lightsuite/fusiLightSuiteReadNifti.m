function [V, info] = fusiLightSuiteReadNifti(filename)
% Read atlas NIfTI-1 or unscaled NIfTI-2 without changing array axis order.
% The published LightSuite vascular atlas is NIfTI-2, unsupported by some
% MATLAB releases. Its native uint16 values are read directly as a fallback.
try
    info=niftiinfo(filename);V=niftiread(info);return;
catch original
end
work=tempname;mkdir(work);clean=onCleanup(@()rmdir(work,'s')); %#ok<NASGU>
if endsWith(filename,'.gz','IgnoreCase',true)
    unpack=gunzip(filename,work);raw=unpack{1};
else,raw=filename;end
fid=fopen(raw,'r','ieee-le');assert(fid>=0,'Cannot open atlas NIfTI.');
c=onCleanup(@()fclose(fid)); %#ok<NASGU>
hdr=fread(fid,1,'int32');
if hdr~=540,error('deConfUSIon:LightSuiteNifti','Cannot read atlas NIfTI: %s',original.message);end
magic=char(fread(fid,8,'uint8')');
assert(startsWith(magic,'n+2'),'deConfUSIon:LightSuiteNifti','Expected a single-file little-endian NIfTI-2 atlas.');
fseek(fid,12,'bof');dtype=fread(fid,1,'int16');bits=fread(fid,1,'int16');
dim=fread(fid,8,'int64')';
assert(dim(1)==3 && all(dim(2:4)>1),'Atlas must be a 3-D NIfTI volume.');
fseek(fid,104,'bof');pixdim=fread(fid,8,'double')';
offset=fread(fid,1,'int64');slope=fread(fid,1,'double');intercept=fread(fid,1,'double');
fseek(fid,500,'bof');units=fread(fid,1,'int32');
assert(bitand(units,7)==2,'Atlas spacing must be expressed in millimetres.');
assert(dtype==512 && bits==16,'deConfUSIon:LightSuiteNifti','Fallback supports the published uint16 vascular atlas only.');
assert(slope==0 || (slope==1&&intercept==0),'deConfUSIon:LightSuiteNifti','Scaled NIfTI-2 needs conversion with a full NIfTI reader.');
fseek(fid,offset,'bof');V=fread(fid,prod(dim(2:4)),'*uint16');
assert(numel(V)==prod(dim(2:4)),'Atlas image data are incomplete.');
V=reshape(V,dim(2:4));
info=struct('ImageSize',dim(2:4),'PixelDimensions',pixdim(2:4), ...
    'SpaceUnits','Millimeter','Version','NIfTI-2','Filename',filename,'reader','native uint16 NIfTI-2 fallback');
end
