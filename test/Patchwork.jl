import Patchwork: override, mend
using Base.Test

# Test the concept of overwritten methods in Julia
let generic() = "foo"
    @test generic() == "foo"
    generic() = "bar"
    @test generic() == "bar"
end

# generic functions that only exist within a let block currently cannot be overwritten (yet)
let generic() = "foo"
    @test generic() == "foo"
    @test_throws UndefVarError Main.generic()

    @test_throws MethodError override(generic, () -> "bar") do
        @test generic() == "bar"  # Note: Never executed
    end

    @test generic() == "foo"
    @test_throws UndefVarError Main.generic()
end

# Non-generic functions can be overridden no matter where they are defined
let anonymous = () -> "foo"
    @test anonymous() == "foo"
    override(anonymous, () -> "bar") do
        @test anonymous() == "bar"
    end
    @test anonymous() == "foo"
end

# Generic functions can be overwritten if they are defined globally within the module
let open = Base.open
    @test_throws SystemError open("foo")

    # Ambigious replacments should raise an exception
    replacement = (name) -> name == "foo" ? "bar" : Original.open(name)
    @test_throws ErrorException mend(() -> nothing, open, replacement)

    @test_throws SystemError open("foo")

    replacement = (name::AbstractString) -> name == "foo" ? IOBuffer("bar") : Original.open(name)
    mend(open, replacement) do
        @test readall(open("foo")) == "bar"
        @test isa(open(tempdir()), IOStream)
    end

    @test_throws SystemError open("foo")
end

# Let blocks seem more forgiving
@test !isfile("foobar.txt")
@test_throws SystemError open("foobar.txt")

mock_open = (name::AbstractString) -> name == "foobar.txt" ? IOBuffer("Hello Julia") : Original.open(name)

mend(open, mock_open) do
    @test readall(open("foobar.txt")) == "Hello Julia"
    @test isa(open(tempdir()), IOStream)
end

@test_throws SystemError open("foobar.txt")


# Replacing isfile is tricky as it uses varargs.
tmp_file = tempname()
@test isfile(tmp_file) == false

mock_isfile = (f::AbstractString) -> f == tmp_file ? true : Original.isfile(f)
mend(isfile, mock_isfile) do
    @test isfile(tmp_file) == true
end

@test isfile(tmp_file) == false
