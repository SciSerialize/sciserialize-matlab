%SERIALIZE_DATA parses Matlab data structures  into a json string
% SERIALIZE_DATA(DATA)
%    creates json strings from Matlab data structures. It implements the
%    SciSerialize format defined on
%    https://github.com/SciSerialize/Definition. The supported data types
%    are datetime, timedelta (in matlab duration) and N dimensional arrays
%    (converted to matlab matrix). For details see the definition webpage.

% (c) 2015 Nils L. Westhausen
% This code is licensed under the BSD 3-clause license

% serializing data-structures to json
function [ json ] = serialize_data( data )
    try
        data = value(data);
    catch err
        error('error by serializing the data to containers.Map');
    end
    json = dumpjson(data);
end

% checking value of data in a recursive way
function obj = value(data)
    if (isnumeric(data) && numel(data) ~= 0 && ...
         (numel(data) > 1 || ~isreal(data)))
         obj = encode_nd_array(data);
    elseif isa(data , 'duration')
        obj = encode_duration(data);
    elseif isa(data , 'datetime')
        obj = encode_datetime(data);
    elseif isstruct(data)
        struct_keys = fieldnames(data);
        obj = struct();
        for idx = 1:length(struct_keys)
            key = struct_keys{idx};
            obj.(key) = value(data.(key));
        end
    elseif iscell(data)
        obj = {};
        for idx = 1:length(data)
            obj{idx} = value(data{idx});
        end
    elseif isa(data, 'containers.Map')
        map_keys = keys(data);
        obj = containers.Map();
        for idx = 1:length(map_keys)
            key = map_keys{idx};
            obj(key) = value(data(key));
        end
    else
        obj = data;
    end
end

% creates map with base64 data of an nd-array
function [map] = encode_nd_array(data)
    if ~isreal(data) && isinteger(data)
        data = double(data); % Numpy does not know complex int
    end
    % convert column-major (Matlab, FORTRAN) to row-major (C, Python)
    data = permute(data, length(size(data)):-1:1);
    % convert to uint8 1-D array
    if isreal(data)
        binary = typecast(data(:), 'uint8');
    else
        % convert [complex, complex] into [real, imag, real, imag]
        tmp = zeros(numel(data)*2, 1);
        if isa(data, 'single')
            tmp = single(tmp);
        end
        tmp(1:2:end) = real(data(:));
        tmp(2:2:end) = imag(data(:));
        binary = typecast(tmp, 'uint8');
    end
    if islogical(data)
        % convert logicals (bool) into one-byte-per-bit
        binary = cast(data,'uint8');
    end
    base64_map = base64encode(binary);
    % translate Matlab class names into numpy dtypes
    if isa(data, 'double') && isreal(data)
        dtype = 'float64';
    elseif isa(data, 'double')
        dtype = 'complex128';
    elseif isa(data, 'single') && isreal(data)
        dtype = 'float32';
    elseif isa(data, 'single')
        dtype = 'complex64';
    elseif isa(data, 'logical')
        dtype = 'bool';
    elseif isinteger(data)
        dtype = class(data);
    else
        return % don't encode
    end
    siz = num2cell(fliplr(size(data)));
    base64_map = containers.Map('__base64__', base64_map);
    keys = {'__type__', 'shape', 'dtype', 'bytes'};
    values = {'ndarray', siz, dtype, base64_map};
    map = containers.Map(keys, values);
end

% creates map a datetime object
function [map] = encode_datetime(data)
     date_string =  char(data,'yyyy-MM-dd''T''HH:mm:ss.SSSS');
     time_zone = char(tzoffset(data));
     if time_zone(1) ~= '-'
         time_zone = ['+' time_zone];
     end
     keys = { '__type__', 'isostr'};
     values = {'datetime', [date_string time_zone]};
     map = containers.Map(keys, values);
end

% creates map a duration object
function [map] = encode_duration(data)
    millisec = milliseconds(data);
    seconds = millisec/1000;
    micro_seconds = round(rem(seconds, 1) * 10^6);
    seconds = fix(seconds);
    keys = { '__type__', 'days', 'seconds', 'microsec'};
    values = {'timedelta', 0, seconds, micro_seconds};
    map = containers.Map(keys, values);
end
