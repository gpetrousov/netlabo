function [] = plot1()

N = [4 5 6 7 8 9 10];
L = size(N);
averageQtime = zeros(1,L(2));


%parfor (i = 1 : L(2), 7)
for i = 1 : L(2)
    %fprintf('hello from thread %d\n', i);
    [averageQtime(i), Throughput, drop_perc] = eatsv3( 10000, N(i), 2, 3, 0.5, 1500);
    %fprintf('hello from thread %d\n', i);
end

plot(averageQtime(1 : end), N(1:end), '-o');
xlabel('queue time');
ylabel('nodes');
end