class Family
  include Relix
  relix do
    primary_key :key
  end
  attr_reader :key
  def initialize(key)
    @key = key
    index!
  end
end

class Person
  include Relix
  relix do
    primary_key :key
    multi :family_key, order: :birthyear
    unique :by_birthyear, on: :key, order: :birthyear
  end
  attr_accessor :key, :family_key, :birthyear
  def initialize(key, family_key, birthyear=nil)
    @key = key
    @family_key = family_key
    @birthyear = birthyear
    index!
  end
end

module FamilyFixture
  def create_families
    @talbott_family = Family.new('talbott')
    @omelia_family = Family.new('omelia')

    @nathaniel = Person.new('nathaniel', 'talbott', 1980)
    @katie = Person.new('katie', 'talbott', 1977)
    @reuben = Person.new('reuben', 'talbott', 2003)
    @annemarie = Person.new('annemarie', 'talbott', 2005)
    @william = Person.new('william', 'talbott', 2006)
    @elaine = Person.new('elaine', 'talbott', 2007)
    @etan = Person.new('etan', 'talbott', 2009)
    @katherine = Person.new('katherine', 'talbott', 2011)
    @talbott_kids = [@reuben, @annemarie, @william, @elaine, @etan, @katherine]
    @talbotts = ([@nathaniel, @katie] + @talbott_kids)

    @duff = Person.new('duff', 'omelia', 1975)
    @kelly = Person.new('kelly', 'omelia', 1974)
    @madeline = Person.new('madeline', 'omelia', 1998)
    @gavin = Person.new('gavin', 'omelia', 2000)
    @keagan = Person.new('keagan', 'omelia', 2002)
    @luke = Person.new('luke', 'omelia', 2004)
    @gabrielle = Person.new('gabrielle', 'omelia', 2006)
    @mackinley = Person.new('mackinley', 'omelia', 2009)
    @logan = Person.new('logan', 'omelia', 2011)
    @omelia_kids = [@madeline, @gavin, @keagan, @luke, @gabrielle, @mackinley, @logan]
    @omelias = ([@duff, @kelly] + @omelia_kids)

    @everyone = (@talbotts + @omelias)
  end
end