%serialize_data parses Matlab data structures  into a json string 
% It is based on the project transplant written by Bastian Bechtold (c) 2014.
% It uses a moddified version of the DUMPJSON function from the transplant
% project.
%   serialize_data(DATA)
%    creates json strings from Matlab data structures It implements the 
%    SciSerialize format deffinied on 
%    https://github.com/SciSerialize/Definition. The supported data types
%    are datetime, timedelta(in matlab duration) and N dimensional arrays
%    (converted to matlab matrix). For details see the deffinition webpage.
%


% (c) 2015 Nils L. Westhausen
% This code is licensed under the BSD 3-clause license

function [ json ] = serialize_data( data )
    try
        if isnumeric(data) && any(size(data) > 1)
            map = encode_nd_array(data);
            json = dumpjson(map);
        elseif isa(data , 'duration')
            map = encode_duration(data);
            json = dumpjson(map);
        elseif isa(data , 'datetime')
            map = encode_datetime(data);
            json = dumpjson(map);
        else
            json = dumpjson();
        end
    catch err
        error('MAP:dump:unknowntype', ...
                  ['can''t serialize ' char(data) ' (' class(data) ')']);
    end
end

% creates map with base64 data of an nd-array
function [map] = encode_nd_array(data)
    if ~isreal(data) && isinteger(data)
        data = double(data); % Numpy does not know complex int
    end
    % convert to uint8 1-D array in row-major order
    dim = size(data);
    if isreal(data)
        if length(dim) > 2
            data = permute(data,[2 1 3:length(dim)]);
        else
            data = permute(data, [2 1]);
        end
        binary = typecast(data(:), 'uint8');
    else
        % convert [complex, complex] into [real, imag, real, imag]
        tmp = zeros(numel(data)*2, 1);
        if isa(data, 'single')
            tmp = single(tmp);
        end
        
        if length(dim) > 2
            data = permute(data,[2 1 3:length(dim)]);
        else
            data = permute(data, [2 1]);
        end
        tmp(1:2:end) = real(data(:));
        tmp(2:2:end) = imag(data(:));
        binary = typecast(tmp, 'uint8');
    end
    if islogical(data)
        % convert logicals (bool) into one-byte-per-bit
        
        if length(dim) > 2
            data = permute(data,[2 1 3:length(dim)]);
        else
            data = permute(data, [2 1]);
        end
        binary = cast(data,'uint8');
    end
    base64 = base64encode(binary);
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
    
    nd_size = num2cell(fliplr(size(data)));
    base64 = containers.Map('__base64__',base64);
    keys = {'shape', 'dtype', 'bytes', '__type__'};
    values = {nd_size, dtype, base64, 'ndarray'};
    map = containers.Map(keys, values);
end

% creates map a datetime object
function [map] = encode_datetime(data)
     date_string =  char(data,'yyyy-MM-dd''T''HH:mm:ss.SSSS');
     time_zone = data.TimeZone;
     keys = {'isostr', '__type__'};
     values = {[date_string time_zone], 'datetime'};
     map = containers.Map(keys, values);
end

% creates map a duration object
function [map] = encode_duration(data)
    millisec = milliseconds(data);
    seconds = millisec/1000;
    micro_seconds = round(mod(seconds, 1) * 10^6);
    seconds = fix(seconds);
    keys = {'days', 'seconds', 'microsec', '__type__'};
    values = {0, seconds, micro_seconds, 'timedelta'};
    map = containers.Map(keys, values);
end
