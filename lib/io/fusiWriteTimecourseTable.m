function fusiWriteTimecourseTable(fid,timeSec,timeMin,values)
% Write time-course columns efficiently without one fprintf call per sample.
% Bounded blocks keep temporary memory small for long acquisitions.
if ~isscalar(fid)||fid<0,error('deConfUSIon:TimecourseExportFile','Invalid output file identifier.');end
timeSec=double(timeSec(:));timeMin=double(timeMin(:));values=double(values(:));
n=numel(timeSec);
if numel(timeMin)~=n||numel(values)~=n
    error('deConfUSIon:TimecourseExportLength','Time and value columns must have equal lengths.');
end
chunkSize=10000;
for first=1:chunkSize:n
    last=min(n,first+chunkSize-1);
    block=[timeSec(first:last).';timeMin(first:last).';values(first:last).'];
    fprintf(fid,'%.6f\t%.6f\t%.6f\n',block);
end
end
