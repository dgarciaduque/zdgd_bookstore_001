CLASS zdgd_populate_book_master_data DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_oo_adt_classrun .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zdgd_populate_book_master_data IMPLEMENTATION.


  METHOD if_oo_adt_classrun~main.

    SELECT FROM zdgd_i_bookmasterdata
      FIELDS bookid
      INTO TABLE @DATA(book_keys).

    IF book_keys IS NOT INITIAL.
      DATA delete_books TYPE TABLE FOR DELETE ZDGD_I_BookMasterData.
      delete_books = VALUE #(
        FOR book_key IN book_keys
          ( %key-BookID = book_key-BookID ) ).

      MODIFY ENTITIES OF ZDGD_I_BookMasterData
        ENTITY Book
        DELETE FROM delete_books
        FAILED DATA(delete_failed)
        REPORTED DATA(delete_reported).

      IF delete_failed-Book IS NOT INITIAL.
        out->write( 'Deleting existing book master data failed.' ).
        RETURN.
      ENDIF.
    ENDIF.

    DATA create_books TYPE TABLE FOR CREATE ZDGD_I_BookMasterData.
    create_books = VALUE #(
      ( %cid = 'EN01' BookName = 'Pride and Prejudice' Author = 'Jane Austen' Language = 'E' )
      ( %cid = 'EN02' BookName = 'To Kill a Mockingbird' Author = 'Harper Lee' Language = 'E' )
      ( %cid = 'EN03' BookName = 'The Great Gatsby' Author = 'F. Scott Fitzgerald' Language = 'E' )
      ( %cid = 'EN04' BookName = '1984' Author = 'George Orwell' Language = 'E' )
      ( %cid = 'EN05' BookName = 'Jane Eyre' Author = 'Charlotte Bronte' Language = 'E' )
      ( %cid = 'EN06' BookName = 'Moby-Dick' Author = 'Herman Melville' Language = 'E' )
      ( %cid = 'EN07' BookName = 'The Catcher in the Rye' Author = 'J. D. Salinger' Language = 'E' )
      ( %cid = 'EN08' BookName = 'The Lord of the Rings' Author = 'J. R. R. Tolkien' Language = 'E' )
      ( %cid = 'EN09' BookName = 'The Hobbit' Author = 'J. R. R. Tolkien' Language = 'E' )
      ( %cid = 'EN10' BookName = 'The Old Man and the Sea' Author = 'Ernest Hemingway' Language = 'E' )
      ( %cid = 'EN11' BookName = 'The Grapes of Wrath' Author = 'John Steinbeck' Language = 'E' )
      ( %cid = 'EN12' BookName = 'Brave New World' Author = 'Aldous Huxley' Language = 'E' )
      ( %cid = 'EN13' BookName = 'The Picture of Dorian Gray' Author = 'Oscar Wilde' Language = 'E' )
      ( %cid = 'EN14' BookName = 'Wuthering Heights' Author = 'Emily Bronte' Language = 'E' )
      ( %cid = 'EN15' BookName = 'The Adventures of Huckleberry Finn' Author = 'Mark Twain' Language = 'E' )
      ( %cid = 'EN16' BookName = 'Little Women' Author = 'Louisa May Alcott' Language = 'E' )
      ( %cid = 'EN17' BookName = 'Frankenstein' Author = 'Mary Shelley' Language = 'E' )
      ( %cid = 'EN18' BookName = 'Dracula' Author = 'Bram Stoker' Language = 'E' )
      ( %cid = 'EN19' BookName = 'The Scarlet Letter' Author = 'Nathaniel Hawthorne' Language = 'E' )
      ( %cid = 'EN20' BookName = 'The Time Machine' Author = 'H. G. Wells' Language = 'E' )
      ( %cid = 'ES01' BookName = 'Don Quijote de la Mancha' Author = 'Miguel de Cervantes' Language = 'S' )
      ( %cid = 'ES02' BookName = 'Cien anos de soledad' Author = 'Gabriel Garcia Marquez' Language = 'S' )
      ( %cid = 'ES03' BookName = 'La casa de los espiritus' Author = 'Isabel Allende' Language = 'S' )
      ( %cid = 'ES04' BookName = 'El amor en los tiempos del colera' Author = 'Gabriel Garcia Marquez' Language = 'S' )
      ( %cid = 'ES05' BookName = 'La sombra del viento' Author = 'Carlos Ruiz Zafon' Language = 'S' )
      ( %cid = 'ES06' BookName = 'Pedro Paramo' Author = 'Juan Rulfo' Language = 'S' )
      ( %cid = 'ES07' BookName = 'Rayuela' Author = 'Julio Cortazar' Language = 'S' )
      ( %cid = 'ES08' BookName = 'La ciudad y los perros' Author = 'Mario Vargas Llosa' Language = 'S' )
      ( %cid = 'ES09' BookName = 'Ficciones' Author = 'Jorge Luis Borges' Language = 'S' )
      ( %cid = 'ES10' BookName = 'La tregua' Author = 'Mario Benedetti' Language = 'S' )
      ( %cid = 'ES11' BookName = 'Como agua para chocolate' Author = 'Laura Esquivel' Language = 'S' )
      ( %cid = 'ES12' BookName = 'La muerte de Artemio Cruz' Author = 'Carlos Fuentes' Language = 'S' )
      ( %cid = 'ES13' BookName = 'Platero y yo' Author = 'Juan Ramon Jimenez' Language = 'S' )
      ( %cid = 'ES14' BookName = 'Fortunata y Jacinta' Author = 'Benito Perez Galdos' Language = 'S' )
      ( %cid = 'ES15' BookName = 'El tunel' Author = 'Ernesto Sabato' Language = 'S' )
      ( %cid = 'ES16' BookName = 'La colmena' Author = 'Camilo Jose Cela' Language = 'S' )
      ( %cid = 'ES17' BookName = 'El Aleph' Author = 'Jorge Luis Borges' Language = 'S' )
      ( %cid = 'ES18' BookName = 'Nada' Author = 'Carmen Laforet' Language = 'S' )
      ( %cid = 'ES19' BookName = 'Los pasos perdidos' Author = 'Alejo Carpentier' Language = 'S' )
      ( %cid = 'ES20' BookName = 'El hobbit' Author = 'J. R. R. Tolkien' Language = 'S' )
      ( %cid = 'FR01' BookName = 'Les Miserables' Author = 'Victor Hugo' Language = 'F' )
      ( %cid = 'FR02' BookName = 'Le Comte de Monte-Cristo' Author = 'Alexandre Dumas' Language = 'F' )
      ( %cid = 'FR03' BookName = 'Madame Bovary' Author = 'Gustave Flaubert' Language = 'F' )
      ( %cid = 'FR04' BookName = 'L''Etranger' Author = 'Albert Camus' Language = 'F' )
      ( %cid = 'FR05' BookName = 'A la recherche du temps perdu' Author = 'Marcel Proust' Language = 'F' )
      ( %cid = 'FR06' BookName = 'Le Petit Prince' Author = 'Antoine de Saint-Exupery' Language = 'F' )
      ( %cid = 'FR07' BookName = 'Notre-Dame de Paris' Author = 'Victor Hugo' Language = 'F' )
      ( %cid = 'FR08' BookName = 'Germinal' Author = 'Emile Zola' Language = 'F' )
      ( %cid = 'FR09' BookName = 'Le Rouge et le Noir' Author = 'Stendhal' Language = 'F' )
      ( %cid = 'FR10' BookName = 'Candide' Author = 'Voltaire' Language = 'F' )
      ( %cid = 'FR11' BookName = 'Le Pere Goriot' Author = 'Honore de Balzac' Language = 'F' )
      ( %cid = 'FR12' BookName = 'Les Fleurs du mal' Author = 'Charles Baudelaire' Language = 'F' )
      ( %cid = 'FR13' BookName = 'Le Tour du monde en quatre-vingts jours' Author = 'Jules Verne' Language = 'F' )
      ( %cid = 'FR14' BookName = 'Vingt mille lieues sous les mers' Author = 'Jules Verne' Language = 'F' )
      ( %cid = 'FR15' BookName = 'Le Grand Meaulnes' Author = 'Alain-Fournier' Language = 'F' )
      ( %cid = 'FR16' BookName = 'Bel-Ami' Author = 'Guy de Maupassant' Language = 'F' )
      ( %cid = 'FR17' BookName = 'La Peste' Author = 'Albert Camus' Language = 'F' )
      ( %cid = 'FR18' BookName = 'Les Liaisons dangereuses' Author = 'Pierre Choderlos de Laclos' Language = 'F' )
      ( %cid = 'FR19' BookName = 'Le Silence de la mer' Author = 'Vercors' Language = 'F' )
      ( %cid = 'FR20' BookName = 'Le Mariage de Figaro' Author = 'Beaumarchais' Language = 'F' )
      ( %cid = 'IT01' BookName = 'La Divina Commedia' Author = 'Dante Alighieri' Language = 'I' )
      ( %cid = 'IT02' BookName = 'I Promessi Sposi' Author = 'Alessandro Manzoni' Language = 'I' )
      ( %cid = 'IT03' BookName = 'Il nome della rosa' Author = 'Umberto Eco' Language = 'I' )
      ( %cid = 'IT04' BookName = 'Se questo e un uomo' Author = 'Primo Levi' Language = 'I' )
      ( %cid = 'IT05' BookName = 'Le avventure di Pinocchio' Author = 'Carlo Collodi' Language = 'I' )
      ( %cid = 'IT06' BookName = 'Il Gattopardo' Author = 'Giuseppe Tomasi di Lampedusa' Language = 'I' )
      ( %cid = 'IT07' BookName = 'Decameron' Author = 'Giovanni Boccaccio' Language = 'I' )
      ( %cid = 'IT08' BookName = 'Orlando furioso' Author = 'Ludovico Ariosto' Language = 'I' )
      ( %cid = 'IT09' BookName = 'I Malavoglia' Author = 'Giovanni Verga' Language = 'I' )
      ( %cid = 'IT10' BookName = 'Il fu Mattia Pascal' Author = 'Luigi Pirandello' Language = 'I' )
      ( %cid = 'IT11' BookName = 'Uno, nessuno e centomila' Author = 'Luigi Pirandello' Language = 'I' )
      ( %cid = 'IT12' BookName = 'Il sentiero dei nidi di ragno' Author = 'Italo Calvino' Language = 'I' )
      ( %cid = 'IT13' BookName = 'Le citta invisibili' Author = 'Italo Calvino' Language = 'I' )
      ( %cid = 'IT14' BookName = 'Cristo si e fermato a Eboli' Author = 'Carlo Levi' Language = 'I' )
      ( %cid = 'IT15' BookName = 'Il barone rampante' Author = 'Italo Calvino' Language = 'I' )
      ( %cid = 'IT16' BookName = 'La coscienza di Zeno' Author = 'Italo Svevo' Language = 'I' )
      ( %cid = 'IT17' BookName = 'Novecento' Author = 'Alessandro Baricco' Language = 'I' )
      ( %cid = 'IT18' BookName = 'Mastro-don Gesualdo' Author = 'Giovanni Verga' Language = 'I' )
      ( %cid = 'IT19' BookName = 'Il visconte dimezzato' Author = 'Italo Calvino' Language = 'I' )
      ( %cid = 'IT20' BookName = 'Gli indifferenti' Author = 'Alberto Moravia' Language = 'I' )
      ( %cid = 'PT01' BookName = 'Os Lusiadas' Author = 'Luis de Camoes' Language = 'P' )
      ( %cid = 'PT02' BookName = 'Memorial do Convento' Author = 'Jose Saramago' Language = 'P' )
      ( %cid = 'PT03' BookName = 'Ensaio sobre a cegueira' Author = 'Jose Saramago' Language = 'P' )
      ( %cid = 'PT04' BookName = 'Dom Casmurro' Author = 'Machado de Assis' Language = 'P' )
      ( %cid = 'PT05' BookName = 'Grande Sertao: Veredas' Author = 'Joao Guimaraes Rosa' Language = 'P' )
      ( %cid = 'PT06' BookName = 'Capitaes da Areia' Author = 'Jorge Amado' Language = 'P' )
      ( %cid = 'PT07' BookName = 'O Primo Basilio' Author = 'Eca de Queiros' Language = 'P' )
      ( %cid = 'PT08' BookName = 'Os Maias' Author = 'Eca de Queiros' Language = 'P' )
      ( %cid = 'PT09' BookName = 'A Hora da Estrela' Author = 'Clarice Lispector' Language = 'P' )
      ( %cid = 'PT10' BookName = 'Quarto de Despejo' Author = 'Carolina Maria de Jesus' Language = 'P' )
      ( %cid = 'PT11' BookName = 'Vidas Secas' Author = 'Graciliano Ramos' Language = 'P' )
      ( %cid = 'PT12' BookName = 'Macunaima' Author = 'Mario de Andrade' Language = 'P' )
      ( %cid = 'PT13' BookName = 'O Auto da Compadecida' Author = 'Ariano Suassuna' Language = 'P' )
      ( %cid = 'PT14' BookName = 'A Moreninha' Author = 'Joaquim Manuel de Macedo' Language = 'P' )
      ( %cid = 'PT15' BookName = 'Iracema' Author = 'Jose de Alencar' Language = 'P' )
      ( %cid = 'PT16' BookName = 'A Paixao Segundo G.H.' Author = 'Clarice Lispector' Language = 'P' )
      ( %cid = 'PT17' BookName = 'Sagarana' Author = 'Joao Guimaraes Rosa' Language = 'P' )
      ( %cid = 'PT18' BookName = 'O Ateneu' Author = 'Raul Pompeia' Language = 'P' )
      ( %cid = 'PT19' BookName = 'Triste Fim de Policarpo Quaresma' Author = 'Lima Barreto' Language = 'P' )
      ( %cid = 'PT20' BookName = 'A Cidade e as Serras' Author = 'Eca de Queiros' Language = 'P' ) ).

    MODIFY ENTITIES OF ZDGD_I_BookMasterData
      ENTITY Book
      CREATE FIELDS ( BookName Author Language )
      WITH create_books
      MAPPED DATA(create_mapped)
      FAILED DATA(create_failed)
      REPORTED DATA(create_reported).

    IF create_failed-Book IS NOT INITIAL.
      out->write( 'Creating book master data failed.' ).
      RETURN.
    ENDIF.

    COMMIT ENTITIES RESPONSE OF ZDGD_I_BookMasterData
      FAILED DATA(commit_failed)
      REPORTED DATA(commit_reported).

    IF commit_failed-Book IS NOT INITIAL.
      out->write( 'Committing book master data failed.' ).
      RETURN.
    ENDIF.

    out->write( 'Book master data populated successfully: 100 entries.' ).

  ENDMETHOD.
ENDCLASS.
