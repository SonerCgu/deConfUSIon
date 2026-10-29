function [labels,values]=gaTitrationDoseChoices()
% Fixed 1/2/5 concentration series from 1 pM through 10 micromolar.
amounts={[1 2 5 10 20 50 100 200 500],[1 2 5 10 20 50 100 200 500],[1 2 5 10]};
units={'pM','nM',[char(181) 'M']};
labels=cell(1,sum(cellfun(@numel,amounts)));values=zeros(size(labels));k=0;
for unit=1:numel(units)
    for amount=amounts{unit}
        k=k+1;labels{k}=sprintf('%g %s',amount,units{unit});
        values(k)=gaTitration('parse',labels{k});
    end
end
end
