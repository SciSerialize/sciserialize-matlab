%% nd_array serialization 
matrix = randn(5,4,3,2,3);
if matrix ~= deserialize_data(serialize_data(matrix));
	error('nd_array serialization failed');
end
%% complex nd_array serialization
complex_matrix = complex(randn(2,3,4,5,3), randn(2,3,4,5,3));
if complex_matrix ~= deserialize_data(serialize_data(complex_matrix));
	error('complex nd_array serialization failed');
end
%% duration serialization
dur = duration(4, 42, 16, 80);
if dur ~= deserialize_data(serialize_data(dur));
	error('duration serialization failed');
end
%% datetime serialization
date_time = datetime();
if date_time ~= deserialize_data(serialize_data(date_time));
	error('datetime serialization failed');
end
%% empty matrix serialization
if  ~isempty(deserialize_data(serialize_data([])));
	error('empty matrix serialization failed');
end