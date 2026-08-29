-- Reverserer 00021: bare Lojale kan stemme igjen. Allerede avgitte stemmer
-- fra sabotører blir stående i saboteur_ballots — de er historiske fakta.
-- Kjør 00011 på nytt for de gamle definisjonene av de tre funksjonene.
delete from schema_migrations where version = '00021_everyone_votes';
