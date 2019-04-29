# pfdb - Personal Movie DataBase
***pfdb*** is a simple command line tool to create and administrate a versatile personal film collection, getting the information from IMDB and FilmAffinity automatically and organizing it neatly. It provides a number of methods for searching (both in the web and in the database), displaying movie cards and lists, filtering, ordering, or plotting interesting graphics (in the future!).

## Summary of available commands

### Search a film on the internet or in the database
- *search(STRING query, STRING web)*

The command will perform a search on the website 'web' with the exact query 'query', and display the top results. These are stored in memory, and one might call the command *add* to add them to the database later on.

The amount of results showed can be configured setting 'search_limit' in the config file.

If only one argument is provided, it will be interpreted as the query, and the search will be performed on the database, matching titles (case insensitive, via a regex match).

### Add a film to the database
- *add(Integer index)*
- *add_movie(String id, String web)*

The command will add the i-th film from the results of the latest search to the database. Thus, at least one search must have been done in the session.

Alternatively, one might want to directly call 'add_movie' with the numerical ID of the film and the corresponding website, both in String formats, to add the film straight to the database without requiring a previous search.

### Delete a film from the database
- *delete(Integer index)*
- *delete(String title)*

The command in its first form will delete from the database the film with the exact index provided. In its second form, it will perform a search, matching via regex, case insensitively. If there's only one result, it will be deleted. Otherwise, the list will be printed.

### View the list of films
- *list(show: INTEGER)*

The command will output a table with the list of films, showing the first ':show' elements. If ommited, the limit is determined by the one established by 'list_limit' in the config file.

### View a summary of a film
- *view(Integer id)*
- *view(String title)*

The command in its first form will show a table summarizing the information of the film with index 'id' in the database. In its second form, it will perform a search in the database with the provided string, matching the titles of the films. If a single result is found, its summary will be shown, otherwise, the list of results will be shown.

### Clean the database
- *clean()*

The command will remove both blank and duplicate entries from the database. If configured, ***pfdb*** will perform a cleansing automatically when opened (default: true).

## Summary of configurable options
Many options can be configured, all of them via editing the config file *config.yml*.

- *autosave*: Boolean to determine whether to save the database automatically after relevant changes, like addition, deletion, cleansing or modification. True by default.
- *autoclean*: Boolean to determine whether to clean the database at the execution of the program. True by default.
- *autobackup*: Boolean to determine whether to make a daily backup of the database (when opened). False by default.

## License and attributions
This project is licensed under the terms of the MIT license (see LICENSE.txt in the root directory of the project).
