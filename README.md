# pfdb - Personal Film DataBase
**pfdb** is a simple command line tool to create and administrate a versatile personal film collection, getting the information from IMDb and FilmAffinity automatically and organizing it neatly. It provides a number of methods for searching (both in the web and in the database), displaying movie cards and lists, filtering, ordering, or plotting interesting graphics (in the future!).

# Table of contents

  * [pfdb - Personal Film DataBase](#pfdb---personal-film-database)
  * [Table of contents](#table-of-contents)
  * [Summary of available functions](#summary-of-available-functions)
    * [Search for films](#search-for-films)
      * [In the web](#in-the-web)
      * [In the database](#in-the-database)
    * [Add films to the database](#add-films-to-the-database)
    * [Delete films from the database](#delete-films-from-the-database)
    * [List the films](#list-the-films)
    * [View the summary of a film](#view-the-summary-of-a-film)
    * [Show the awards of a film](#show-the-awards-of-a-film)
    * [Clean the database](#clean-the-database)
  * [Summary of configurable options](#summary-of-configurable-options)
  * [Summary of retrieved film details](#summary-of-retrieved-film-information)
  * [License](#license)

# Summary of available commands

## Search for films

### In the web
```ruby
search(STRING query, STRING web)
```
If two arguments are provided, pfdb will perform a search on the website *web* with the exact query *query*, and retrieve the top results. These are stored in memory, and one might call the command *add* to add them to the database later on. The amount of results showed can be configured setting *search_limit* in the config file.

### In the database
```ruby
search(STRING query)
```
If only one argument is provided, it will be interpreted as the *query*, and the search will be performed on the database, matching titles via a simple case insensitive regex match.

## Add films to the database
```ruby
add(Integer index)
add_movie(String id, String web)
```
The first command will add the *index*-th film from the results of the latest search to the database, thus, at least one search must have been performed in the session. This function retrieves plenty of relevant information and details of the selected film from IMDb and / or FilmAffinity which is then stored in the database. For a full list of retrieved details, see this [summary](#summary-of-retrieved-film-information).

Alternatively, one might want to directly call the second command with the numerical ID of the film and the corresponding website (IMDb or FilmAffinity), both in String formats, to add the film straight to the database without requiring a previous search.

## Delete films from the database
```ruby
delete(Integer index)
delete(String title)
```
The command in its first form will delete from the database the film with the exact index provided. In its second form, it will perform a search, matching via case insensitive regex. If there's only one result, it will be deleted. Otherwise, the list will be printed.

## List the films
```ruby
list(show: INTEGER)
```
The command will output a table with the list of films, showing the first ':show' elements. If ommited, the limit is determined by the one established by 'list_limit' in the config file.

## View the summary of a film
```ruby
view(Integer id)
view(String title)
```
The command in its first form will show a table summarizing the information of the film with index *id* in the database. In its second form, it will perform a search in the database with the provided string, matching the titles of the films. If a single result is found, its summary will be shown, otherwise, the list of results will be shown.

## Show the awards of a film
```ruby
awards(Integer id)
awards(String title)
```
The command in its first form will show a table summarizing the prizes awarded to that film. The full list of awards retrieved from IMDb can be consulted in the corresponding [summary](#summary-of-retrieved-film-information). In its second form, it will perform a search, matching via case insensitive regex. If there's only one result, its award summary will be shown. Otherwise, the list will be printed.

## Clean the database
```ruby
clean()
```
The command will remove both blank and duplicate entries from the database. If configured, **pfdb** will perform a cleansing automatically when opened (default: true).

# Summary of configurable options
Many options can be configured, all of them via editing the config file *config.yml*.

- *json*: Name of the database name. Default: **pfdb.json**.
- *language*: [ES / EN] Language, currently its only effect is on FilmAffinitys default language. Default: **ES**.
- *autolog*: [True / False] Determines whether to automatically register relevant information to the log file. Default: **True**.
- *autosave*: [True / False] Determines whether to save the database automatically after relevant changes, like addition, deletion, cleansing or modification. Default: **True**.
- *autoclean*: [True / False] Determines whether to clean the database at the execution of the program. Default: **True**.
- *autobackup*: [True / False] Determines whether to make a daily backup of the database (when opened). Default: **False**.
- *cast_amount*: The max number of cast members retrieved from IMDb for each film. Default: **20**.
- *cast_list*: The max number of cast members shown in the film summaries. Default: **10**.
- *search_limit*: The max number of results for search results. Default: **20**.
- *list_limit*: The max number of results for film lists. Default: **20**.
- *list_separation*: Number of films in the list between each separating line. Default: **5**.
- *movie_card_width*: Width in characters of each film summary. Default: **120**.
- *movie_card_field_length_limit*: Maximum character length of the synopsis shown in the summary. Default: **600**.

# Summary of retrieved film details
Currently **pfdb** retrieves the following film information from its IMDb page:

- *Basic details*: Film title, original title, duration, year, countries, genres, synopsis, and films ID.
- *Crew*: Cast (both real and character names), directors, writers, producers, composers, cinematographers, editors, casting directors, and producing companies.
- *Technical details*: Color, budget, gross revenue, and languages.
- *IMDb specs*: Film rating, number of votes, and position in the Top250 ranking (if).
- *Awards*: Oscars, Golden Globes, BAFTAS, Goyas, Grammys, and Writers Guild Awards.

It also retrieves the following additional information from FilmAffinity:

- Spanish synopsis, film rating, number of votes, relations to other films (sequel / sequel of / prequel ...), and films ID.

Finally, **pfdb** also stores the following details for each film:

- Date added to the database, dates viewed, personal rating and personal comment.

# License
This project is licensed under the terms of the MIT license (see LICENSE.txt in the root directory of the project).
