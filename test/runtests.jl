using SQLiteGraph
using Test

@testset "SQLiteGraph.jl" begin
    @testset "empty DB" begin 
        db = DB()
        @test length(db) == 0 
        @test size(db) == (nodes=0, edges=0)
        @test_throws BoundsError db[5]
        @test isnothing(db[1,2])
    end
end
