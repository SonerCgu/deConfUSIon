function acronym=fusiAtlasDisplayAcronym(acronym)
% Parent-unassigned parcels are real parent tissue, not missing labels.
% Keep the source full name/ID to distinguish them from named subdivisions.
acronym=regexprep(strtrim(char(acronym)),'(?i)[_ -]+unassigned$','');
end
