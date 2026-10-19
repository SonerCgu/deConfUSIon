function [display,state]=fusiProgressDisplay(fraction,stage,elapsed,state)
% Display the current transfer/read phase, not a weighted pipeline fraction.
% Existing two-argument progress callbacks remain compatible. Counts in the
% loader's status text carry the real byte/frame progress through wrappers
% that scale the overall fraction for the rest of the Studio transaction.
if nargin<4||isempty(state),state=struct('key','','started',0,'firstFraction',0,'staged',false);end
display=struct('fraction',fraction,'status',stage,'estimate', ...
    ['Elapsed ' durationText(elapsed)],'remainingSeconds',NaN,'phase','');
key='';phaseFraction=NaN;remainingLabel='';
counts=regexp(stage,'^Copying network MAT:\s*([\d.]+)\s*/\s*([\d.]+)\s*MB','tokens','once');
if ~isempty(counts)
    key='network-copy';phaseFraction=str2double(counts{1})/max(eps,str2double(counts{2}));
    remainingLabel='Copy remaining';
elseif startsWith(stage,'Copying network MAT file to local read cache')
    key='network-copy';phaseFraction=0;remainingLabel='Copy remaining';
elseif startsWith(stage,'Preparing PCA component removal')
    key='pca-removal';phaseFraction=0;remainingLabel='Removal remaining';
elseif startsWith(stage,'Removing selected PCs:')
    counts=regexp(stage,'^Removing selected PCs:\s*(\d+)\s*/\s*(\d+)\s*frames','tokens','once');
    if ~isempty(counts)
        key='pca-removal';phaseFraction=str2double(counts{1})/max(1,str2double(counts{2}));
        remainingLabel='Removal remaining';
    end
else
    counts=regexp(stage,'^Reading (.+?):\s*(\d+)\s*/\s*(\d+)\s*frames','tokens','once');
    if ~isempty(counts)
        key=['read:' counts{1}];phaseFraction=str2double(counts{2})/max(1,str2double(counts{3}));
        remainingLabel='Read remaining';
    elseif ~isnan(fraction)
        name=regexp(stage,'^Reading (.+?)\.\.\.$','tokens','once');
        if ~isempty(name)&&(state.staged||endsWith(name{1},' from local cache'))
            key=['read:' name{1}];phaseFraction=0;remainingLabel='Read remaining';
        end
    end
end
if ~isempty(key)
    phaseFraction=min(1,max(0,phaseFraction));
    if ~strcmp(state.key,key)||phaseFraction<state.firstFraction
        state.key=key;state.started=elapsed;state.firstFraction=phaseFraction;
    end
    state.staged=true;display.phase=key;display.fraction=phaseFraction;
    display.status=sprintf('%s  (%d%%)',stage,round(100*phaseFraction));
    delta=phaseFraction-state.firstFraction;phaseElapsed=max(0,elapsed-state.started);
    if phaseFraction>=1
        display.remainingSeconds=0;display.estimate=[remainingLabel ': complete'];
    elseif delta>=.02&&phaseElapsed>=1
        remaining=phaseElapsed*(1-phaseFraction)/delta;display.remainingSeconds=remaining;
        display.estimate=sprintf('%s: about %s',remainingLabel,durationText(remaining));
    else
        display.estimate=[remainingLabel ': estimating...'];
    end
    if strcmp(key,'network-copy')
        display.estimate=[display.estimate ' | local read follows'];
    end
elseif isnan(fraction)
    display.estimate=sprintf('Elapsed %s',durationText(elapsed));
elseif fraction>=1
    display.fraction=1;display.status=sprintf('%s  (100%%)',stage);
elseif state.staged
    % Final metadata/folder work has no measured rate. Do not extrapolate a
    % whole-load ETA from arbitrary progress weights after the transfer.
    display.fraction=min(1,max(0,fraction));
else
    display.fraction=min(1,max(0,fraction));
    display.status=sprintf('%s  (%d%%)',stage,round(100*display.fraction));
    if display.fraction>=.02&&elapsed>=1
        remaining=elapsed*(1-display.fraction)/display.fraction;display.remainingSeconds=remaining;
        display.estimate=sprintf('Elapsed %s | about %s remaining',durationText(elapsed),durationText(remaining));
    else
        display.estimate='Estimating remaining time...';
    end
end
end

function text=durationText(seconds)
seconds=max(0,round(seconds));
if seconds<60,text=sprintf('%d s',seconds);
elseif seconds<3600,text=sprintf('%d min %02d s',floor(seconds/60),mod(seconds,60));
else,text=sprintf('%d h %02d min',floor(seconds/3600),floor(mod(seconds,3600)/60));end
end
