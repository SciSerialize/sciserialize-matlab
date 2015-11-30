%DESERIALIZE_DATA parses a json string into Matlab data structures
% DESERIALIZE_DATA(STRING)
%    reads STRING as JSON data, and creates Matlab data structures
%    from it. It decodes the SciSerialize format defined on
%    https://github.com/SciSerialize/Definition. The supported data types
%    are datetime, timedelta(in matlab duration) and N dimensional arrays
%    (converted to matlab matrix). For details see the definition webpage.

% (c) 2015 Nils L. Westhausen
% This code is licensed under the BSD 3-clause license

function [obj] = deserialize_data(data)
    obj = parsejson(data);
    try
        obj = type_decoder(obj);
    catch
        error('parsing to MATLAB data structure has failed');
    end
end

% decoding type and calling the decoding functions
function [obj] = type_decoder(data)
    if iscell(data)
        obj = {};
        for idx = 1:length(data)
            obj{idx} = type_decoder(data{idx});
        end
    elseif isstruct(data)
        struct_keys = fieldnames(data);
        obj = struct();
        for idx = 1:length(struct_keys)
            key = struct_keys{idx};
            obj.(key) = type_decoder(data.(key));
        end
    elseif isa(data, 'containers.Map') && isKey(data, '__type__')
        if strcmp(data('__type__'), 'datetime')
            obj = datetime_decoder(data);
        elseif strcmp(data('__type__'), 'timedelta')
            obj = timedelta_decoder(data);
        elseif strcmp(data('__type__'), 'ndarray')
            obj = nd_array_decoder(data);
        else
            warning('unknown "__type__", throwing unprocessed containers.Map')
            obj = data;
        end
    elseif isa(data, 'containers.Map')
        map_keys = keys(data);
        obj = containers.Map();
        for idx = 1:length(map_keys)
            key = map_keys{idx};
            obj(key) = type_decoder(data(key));
        end
    else
        obj = data;
    end
end

% decodes datetimes to the matlab datetime class
function obj = datetime_decoder(map)
    time_str = map('isostr');
    % if there is no fractional digit, there will be one added for parsing
    if isempty(regexp(time_str, '\d\d:\d\d:\d\d\.\d', 'match'))
        time_str = regexprep(time_str, '(\d\d:\d\d:\d\d)', '$1\.0');
    end
    timezone = regexp(time_str(end-5:end), '([-+]\d\d(:\d\d)?)|Z', 'match');
    if isempty(timezone)
        obj = datetime(time_str, ...
        'InputFormat', 'yyyy-MM-dd''T''HH:mm:ss.SSSS');
    else
        zone = timezone{1};
        obj = datetime(time_str, ...
        'InputFormat', 'yyyy-MM-dd''T''HH:mm:ss.SSSSXXX', ...
        'TimeZone', zone, ...
        'Format', 'yyyy-MM-dd''T''HH:mm:ss.SSSSXXX');
    end
end

% decodes time-delta to the matlab duration class
function obj = timedelta_decoder(map)
    % all of this types are of the class duration
    day = days(map('days'));
    second = seconds(map('seconds'));
    millisec = duration(0, 0, 0, (map('microsec') / 10^3));
    obj = millisec + day + second;
end

% decodes nd-arrays to n dimensional matlab matrixes
function obj = nd_array_decoder(map)
    bytes = map('bytes');
    binary = base64decode(bytes('__base64__'));
    dtype = map('dtype');
    dim = cell2mat(map('shape'));
    if length(dim) == 1
        dim = [1 dim];
    end
    % translate numpy dtypes into Matlab class names
    if strcmp(dtype, 'complex128')
        data = typecast(binary, 'double')';
        data = data(1:2:end) + 1i*data(2:2:end);
    elseif strcmp(dtype, 'float64')
        data = typecast(binary, 'double')';
    elseif strcmp(dtype, 'complex64')
        data = typecast(binary, 'single')';
        data = data(1:2:end) + 1i*data(2:2:end);
    elseif strcmp(dtype, 'float32')
        data = typecast(binary, 'single')';
    elseif strcmp(dtype, 'bool')
        data = logical(binary);
    else
        data = typecast(binary, dtype);
    end
    data = reshape(data, fliplr(dim));
    % convert row-major (C, Python) to column-major (Matlab, FORTRAN)
    obj = permute(data, length(dim):-1:1);
end
