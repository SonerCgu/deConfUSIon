function result=fusiLightSuiteFitProgress(action,varargin)
% Scoped registration progress: fractions refer to the CURRENT stage only.
persistent callback stage lastPrinted lastMessage context
result=[];
switch action
    case 'begin'
        assert(isempty(stage),'deConfUSIon:LightSuiteBusy','Another LightSuite fit is already running in this MATLAB session.');
        callback=varargin{1};stage='Preparing fit';lastPrinted=-Inf;lastMessage='';
        context=struct();if numel(varargin)>1,context=varargin{2};end
        result=onCleanup(@()fusiLightSuiteFitProgress('end'));
    case 'end'
        callback=[];stage='';lastPrinted=-Inf;lastMessage='';context=[];
    case 'stage'
        stage=varargin{1};lastPrinted=-Inf;lastMessage='';
        fusiLightSuiteFitProgress('update',NaN,'Working...');
    case 'update'
        fraction=varargin{1};message=varargin{2};
        if isempty(stage),return;end
        label=sprintf('%s | %s',stage,message);
        if isa(callback,'function_handle'),callback(fraction,label);end
        percent=floor(100*fraction);
        if (isnan(fraction)&&~strcmp(label,lastMessage))||percent>=lastPrinted+5||(fraction>=1&&~strcmp(label,lastMessage))
            if isnan(fraction),fusiLightSuiteLog('WORKING',context,label);
            else,fusiLightSuiteLog('WORKING',context,'%s | current stage %d%%',label,percent);end
            if ~isnan(percent),lastPrinted=percent;end
        end
        lastMessage=label;
end
end
