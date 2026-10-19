function [status,result]=fusiLightSuiteRunElastix(command,folder,parameterFiles)
% Run Elastix directly, retaining its log and servicing cancellable GUI progress.
args=regexp(command,'"[^"]*"|\S+','match');
for k=1:numel(args),args{k}=regexprep(args{k},'^"|"$','');end
binary=args{1};if ispc,binary=[binary '.exe'];end
paths=strsplit(getenv('PATH'),pathsep);
for k=1:numel(paths)
    candidate=fullfile(paths{k},binary);
    if isfile(candidate),args{1}=candidate;break;end
end
assert(isfile(args{1}),'deConfUSIon:LightSuiteExecutable','Elastix executable could not be resolved from the configured dependency paths.');
limits=1000;nres=1;
if ~isempty(parameterFiles)&&isfile(parameterFiles{1})
    params=fileread(parameterFiles{1});
    token=regexp(params,'\(MaximumNumberOfIterations\s+([^)]*)\)','tokens','once');
    if ~isempty(token),limits=sscanf(token{1},'%f')';end
    token=regexp(params,'\(NumberOfResolutions\s+(\d+)\)','tokens','once');
    if ~isempty(token),nres=str2double(token{1});end
end
if isscalar(limits),limits=repmat(limits,1,nres);end
if numel(limits)~=nres||any(~isfinite(limits)|limits<=0),limits=1000*ones(1,nres);end
logFile=[tempname(folder) '_console.log'];
commandArgs=java.util.ArrayList();
for k=1:numel(args),commandArgs.add(args{k});end
builder=java.lang.ProcessBuilder(commandArgs);
builder.redirectErrorStream(true);builder.redirectOutput(java.io.File(logFile));
builder.environment().put('PATH',getenv('PATH'));
process=builder.start();cleanup=onCleanup(@()stopProcess(process)); %#ok<NASGU>
offset=0;partial='';resolution=1;iteration=0;
currentFraction=NaN;currentMessage='Initializing or processing images; see retained Elastix log.';
while process.isAlive()
    readProgress();drawnow limitrate;pause(.2);
end
readProgress();status=process.exitValue();result=fileread(logFile);
if status~=0
    tail=result(max(1,end-6000):end);
    error('deConfUSIon:LightSuiteElastixFailed','Elastix exited with code %d. Log: %s\n%s',status,logFile,tail);
end
fusiLightSuiteFitProgress('update',1,'Optimization finished; reading result and diagnostic images...');
    function readProgress()
        fid=fopen(logFile,'r');if fid<0,return;end
        closeLog=onCleanup(@()fclose(fid));fseek(fid,offset,'bof');chunk=fread(fid,Inf,'*char')';offset=ftell(fid); %#ok<NASGU>
        parts=regexp([partial chunk],'\r\n|\n|\r','split');partial=parts{end};parts(end)=[];
        changed=false;
        for j=1:numel(parts)
            match=regexp(parts{j},'^Resolution:\s*(\d+)','tokens','once');
            if ~isempty(match),resolution=min(nres,str2double(match{1})+1);iteration=0;changed=true;end
            match=regexp(parts{j},'^\s*(\d+)\t[-+\d.]','tokens','once');
            if ~isempty(match),iteration=min(limits(resolution),str2double(match{1})+1);changed=true;end
        end
        if changed
            fraction=(sum(limits(1:resolution-1))+iteration)/sum(limits);
            currentFraction=min(.999,fraction);currentMessage=sprintf( ...
                'Resolution %d/%d; iteration %d/%d (configured iteration budget)',resolution,nres,iteration,limits(resolution));
        end
        % Keep cancellation responsive even when the native executable has
        % not emitted another line (pyramid creation, initialization, etc.).
        fusiLightSuiteFitProgress('update',currentFraction,currentMessage);
    end
end
function stopProcess(process)
if process.isAlive(),process.destroyForcibly();end
end
