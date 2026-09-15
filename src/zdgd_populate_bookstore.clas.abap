CLASS zdgd_populate_bookstore DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_oo_adt_classrun .
  PROTECTED SECTION.
  PRIVATE SECTION.

    CONSTANTS:
      bookstore_count TYPE i VALUE 20,
      book_count      TYPE i VALUE 10.
ENDCLASS.



CLASS zdgd_populate_bookstore IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.
    " EML has no "read all instances" primitive, so a plain field select is used only to discover existing keys.

    DATA bookstore_create TYPE TABLE FOR CREATE zdgd_i_bookstore.
    DATA book_link        TYPE TABLE FOR CREATE zdgd_i_bookstore\_books.

    DATA(cities) = VALUE string_table(
      ( `New York` ) ( `London` ) ( `Paris` ) ( `Tokyo` ) ( `Berlin` )
      ( `Rome` ) ( `Madrid` ) ( `Amsterdam` ) ( `Vienna` ) ( `Prague` )
      ( `Dublin` ) ( `Edinburgh` ) ( `Barcelona` ) ( `Lisbon` ) ( `Copenhagen` )
      ( `Stockholm` ) ( `Sydney` ) ( `Toronto` ) ( `San Francisco` ) ( `Chicago` ) ).

    DATA(bookstore_names) = VALUE string_table(
      ( `The Reading Nook` ) ( `Paper Trail Books` ) ( `Chapter One` ) ( `Inkwell & Co.` ) ( `The Book Cellar` )
      ( `Turning Pages` ) ( `The Literary Attic` ) ( `Bound & Lettered` ) ( `The Dusty Shelf` ) ( `Wordsmith Books` )
      ( `The Hidden Library` ) ( `Ink & Paper` ) ( `The Bookworm's Den` ) ( `Storyline Books` ) ( `The Final Chapter` )
      ( `Prose & Cons` ) ( `The Book Nook` ) ( `Between the Lines` ) ( `A Novel Idea` ) ( `Quill & Parchment` ) ).

    DATA(book_titles) = VALUE string_table(
      ( `Pride and Prejudice` ) ( `1984` ) ( `To Kill a Mockingbird` ) ( `The Great Gatsby` ) ( `Moby-Dick` )
      ( `War and Peace` ) ( `The Catcher in the Rye` ) ( `Crime and Punishment` ) ( `One Hundred Years of Solitude` ) ( `The Lord of the Rings` ) ).

    DATA(book_authors) = VALUE string_table(
      ( `Jane Austen` ) ( `George Orwell` ) ( `Harper Lee` ) ( `F. Scott Fitzgerald` ) ( `Herman Melville` )
      ( `Leo Tolstoy` ) ( `J.D. Salinger` ) ( `Fyodor Dostoevsky` ) ( `Gabriel Garcia Marquez` ) ( `J.R.R. Tolkien` ) ).

    SELECT bookstoreid FROM zdgd_i_bookstore INTO TABLE @DATA(existing_ids).

    IF existing_ids IS NOT INITIAL.
      MODIFY ENTITIES OF zdgd_i_bookstore
             ENTITY bookstore
             DELETE FROM VALUE #( FOR id IN existing_ids
                                  ( bookstoreid = id-bookstoreid ) )
             " TODO: variable is assigned but never used (ABAP cleaner)
             FAILED DATA(delete_failed)
             " TODO: variable is assigned but never used (ABAP cleaner)
             REPORTED DATA(delete_reported).

      COMMIT ENTITIES RESPONSE OF zdgd_i_bookstore
        " TODO: variable is assigned but never used (ABAP cleaner)
             FAILED DATA(delete_commit_failed)
             " TODO: variable is assigned but never used (ABAP cleaner)
             REPORTED DATA(delete_commit_reported).
    ENDIF.

    DO bookstore_count TIMES.
      DATA(cid) = |BS{ sy-index WIDTH = 2 ALIGN = RIGHT PAD = '0' }|.

      APPEND VALUE #( %cid          = cid
                      bookstorename = bookstore_names[ sy-index ]
                      city          = cities[ sy-index ] )
             TO bookstore_create.

      APPEND INITIAL LINE TO book_link ASSIGNING FIELD-SYMBOL(<book_link_row>).
      <book_link_row>-%cid_ref = cid.

      DO book_count TIMES.
        APPEND VALUE #( %cid     = |{ cid }BK{ sy-index WIDTH = 2 ALIGN = RIGHT PAD = '0' }|
                        bookname = book_titles[ sy-index ]
                        author   = book_authors[ sy-index ] )
               TO <book_link_row>-%target.
      ENDDO.
    ENDDO.

    MODIFY ENTITIES OF zdgd_i_bookstore
           ENTITY Bookstore
           CREATE FIELDS ( bookstorename city ) WITH bookstore_create
           CREATE BY \_books FIELDS ( bookname author ) WITH book_link
           " TODO: variable is assigned but never used (ABAP cleaner)
           MAPPED DATA(create_mapped)
           " TODO: variable is assigned but never used (ABAP cleaner)
           FAILED DATA(create_failed)
           " TODO: variable is assigned but never used (ABAP cleaner)
           REPORTED DATA(create_reported).

    COMMIT ENTITIES RESPONSE OF zdgd_i_bookstore
           FAILED DATA(create_commit_failed)
           " TODO: variable is assigned but never used (ABAP cleaner)
           REPORTED DATA(create_commit_reported).

    IF create_commit_failed-bookstore IS NOT INITIAL OR create_commit_failed-book IS NOT INITIAL.
      out->write( 'Errors occurred while creating test data.' ).
    ELSE.
      out->write( |{ lines( bookstore_create ) } bookstores and { bookstore_count * book_count } books created.| ).
    ENDIF.
  ENDMETHOD.
ENDCLASS.

