--
-- PostgreSQL database dump
--

\restrict HrK9WOEXcWw67ANSsqvmdNg93KcJQvRmfRhRev9IjWyMLZHf857N25eiWmrjOXH

-- Dumped from database version 16.14 (Debian 16.14-1.pgdg13+1)
-- Dumped by pg_dump version 16.14 (Debian 16.14-1.pgdg13+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA public IS '';


--
-- Name: parser_format; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.parser_format AS ENUM (
    'auchan.paper.v1',
    'leclerc.paper.v1',
    'leclerc.paper.v2',
    'leclerc.web.v1',
    'u.paper.v1',
    'u.paper.v2'
);


--
-- Name: receipt_line_kind; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.receipt_line_kind AS ENUM (
    'item',
    'fee',
    'discount'
);


--
-- Name: receipt_line_unit_of_measure; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.receipt_line_unit_of_measure AS ENUM (
    'piece',
    'kg',
    'g',
    'l',
    'ml'
);


--
-- Name: receipt_parser_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.receipt_parser_status AS ENUM (
    'parsed',
    'needs_review',
    'reviewed'
);


--
-- Name: receipt_payment_category; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.receipt_payment_category AS ENUM (
    'bank_card',
    'tickets_restaurant',
    'cash',
    'web',
    'other'
);


--
-- Name: receipt_promotion_kind; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.receipt_promotion_kind AS ENUM (
    'loyalty_credit',
    'immediate_discount',
    'coupon',
    'points_accrual'
);


--
-- Name: receipt_promotion_linking_method; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.receipt_promotion_linking_method AS ENUM (
    'parser_inferred',
    'user_confirmed',
    'unallocated'
);


--
-- Name: receipt_promotion_unit; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.receipt_promotion_unit AS ENUM (
    'euro_cents',
    'vignette_count'
);


--
-- Name: source_document_mime_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.source_document_mime_type AS ENUM (
    'application/pdf',
    'image/png',
    'image/jpeg'
);


--
-- Name: store_channel; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.store_channel AS ENUM (
    'physical',
    'drive',
    'click_collect'
);


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: active_storage_attachments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_attachments (
    id bigint NOT NULL,
    name character varying NOT NULL,
    record_type character varying NOT NULL,
    record_id bigint NOT NULL,
    blob_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: active_storage_attachments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_attachments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_attachments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_attachments_id_seq OWNED BY public.active_storage_attachments.id;


--
-- Name: active_storage_blobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_blobs (
    id bigint NOT NULL,
    key character varying NOT NULL,
    filename character varying NOT NULL,
    content_type character varying,
    metadata text,
    service_name character varying NOT NULL,
    byte_size bigint NOT NULL,
    checksum character varying,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: active_storage_blobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_blobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_blobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_blobs_id_seq OWNED BY public.active_storage_blobs.id;


--
-- Name: active_storage_variant_records; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_variant_records (
    id bigint NOT NULL,
    blob_id bigint NOT NULL,
    variation_digest character varying NOT NULL
);


--
-- Name: active_storage_variant_records_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_variant_records_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_variant_records_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_variant_records_id_seq OWNED BY public.active_storage_variant_records.id;


--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: receipt_lines; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.receipt_lines (
    id bigint NOT NULL,
    receipt_id bigint NOT NULL,
    "position" integer NOT NULL,
    raw_text text NOT NULL,
    label text NOT NULL,
    label_truncated boolean DEFAULT false NOT NULL,
    quantity numeric(10,3) DEFAULT 1.0 NOT NULL,
    unit_of_measure public.receipt_line_unit_of_measure DEFAULT 'piece'::public.receipt_line_unit_of_measure NOT NULL,
    unit_price_cents integer,
    total_cents integer NOT NULL,
    vat_rate_bp integer,
    tr_eligible boolean DEFAULT false NOT NULL,
    section_label text,
    kind public.receipt_line_kind DEFAULT 'item'::public.receipt_line_kind NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: receipt_lines_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.receipt_lines_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: receipt_lines_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.receipt_lines_id_seq OWNED BY public.receipt_lines.id;


--
-- Name: receipt_payments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.receipt_payments (
    id bigint NOT NULL,
    receipt_id bigint NOT NULL,
    "position" integer NOT NULL,
    raw_label text NOT NULL,
    category public.receipt_payment_category NOT NULL,
    amount_cents integer NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT receipt_payments_amount_cents_positive CHECK ((amount_cents > 0))
);


--
-- Name: receipt_payments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.receipt_payments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: receipt_payments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.receipt_payments_id_seq OWNED BY public.receipt_payments.id;


--
-- Name: receipt_promotions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.receipt_promotions (
    id bigint NOT NULL,
    receipt_id bigint NOT NULL,
    program character varying NOT NULL,
    unit public.receipt_promotion_unit NOT NULL,
    delta integer NOT NULL,
    label text,
    linked_line_id bigint,
    kind public.receipt_promotion_kind NOT NULL,
    linking_method public.receipt_promotion_linking_method NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT receipt_promotions_linking_method_matches_link CHECK ((((linked_line_id IS NULL) AND (linking_method = 'unallocated'::public.receipt_promotion_linking_method)) OR ((linked_line_id IS NOT NULL) AND (linking_method = ANY (ARRAY['parser_inferred'::public.receipt_promotion_linking_method, 'user_confirmed'::public.receipt_promotion_linking_method])))))
);


--
-- Name: receipt_promotions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.receipt_promotions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: receipt_promotions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.receipt_promotions_id_seq OWNED BY public.receipt_promotions.id;


--
-- Name: receipts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.receipts (
    id bigint NOT NULL,
    store_id bigint NOT NULL,
    source_document_id bigint NOT NULL,
    text_extraction_id bigint NOT NULL,
    parser_format public.parser_format NOT NULL,
    purchased_at timestamp(6) without time zone,
    register_number character varying,
    ticket_number character varying,
    cashier_code character varying,
    total_cents integer,
    declared_article_count integer,
    parser_status public.receipt_parser_status DEFAULT 'needs_review'::public.receipt_parser_status NOT NULL,
    parser_warnings jsonb DEFAULT '[]'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: COLUMN receipts.purchased_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.receipts.purchased_at IS 'Wall-clock local transaction time, stored as printed or implied with no timezone offset applied. Drive and Click & Collect receipts use the PDF order-confirmation time.';


--
-- Name: receipts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.receipts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: receipts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.receipts_id_seq OWNED BY public.receipts.id;


--
-- Name: retail_brands; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.retail_brands (
    id bigint NOT NULL,
    name character varying NOT NULL,
    slug character varying NOT NULL,
    aliases jsonb DEFAULT '[]'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: retail_brands_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.retail_brands_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: retail_brands_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.retail_brands_id_seq OWNED BY public.retail_brands.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: source_documents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.source_documents (
    id bigint NOT NULL,
    content_hash character varying NOT NULL,
    mime_type public.source_document_mime_type NOT NULL,
    ingested_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    store_id bigint NOT NULL,
    parser_format public.parser_format NOT NULL
);


--
-- Name: source_documents_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.source_documents_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: source_documents_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.source_documents_id_seq OWNED BY public.source_documents.id;


--
-- Name: stores; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.stores (
    id bigint NOT NULL,
    retail_brand_id bigint NOT NULL,
    location_name character varying NOT NULL,
    channel public.store_channel NOT NULL,
    address text,
    identifiers jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: stores_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.stores_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: stores_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.stores_id_seq OWNED BY public.stores.id;


--
-- Name: text_extractions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.text_extractions (
    id bigint NOT NULL,
    source_document_id bigint NOT NULL,
    engine character varying NOT NULL,
    text text DEFAULT ''::text NOT NULL,
    ran_at timestamp(6) without time zone NOT NULL,
    success boolean DEFAULT false NOT NULL,
    error_message text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: text_extractions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.text_extractions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: text_extractions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.text_extractions_id_seq OWNED BY public.text_extractions.id;


--
-- Name: active_storage_attachments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments ALTER COLUMN id SET DEFAULT nextval('public.active_storage_attachments_id_seq'::regclass);


--
-- Name: active_storage_blobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs ALTER COLUMN id SET DEFAULT nextval('public.active_storage_blobs_id_seq'::regclass);


--
-- Name: active_storage_variant_records id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records ALTER COLUMN id SET DEFAULT nextval('public.active_storage_variant_records_id_seq'::regclass);


--
-- Name: receipt_lines id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.receipt_lines ALTER COLUMN id SET DEFAULT nextval('public.receipt_lines_id_seq'::regclass);


--
-- Name: receipt_payments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.receipt_payments ALTER COLUMN id SET DEFAULT nextval('public.receipt_payments_id_seq'::regclass);


--
-- Name: receipt_promotions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.receipt_promotions ALTER COLUMN id SET DEFAULT nextval('public.receipt_promotions_id_seq'::regclass);


--
-- Name: receipts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.receipts ALTER COLUMN id SET DEFAULT nextval('public.receipts_id_seq'::regclass);


--
-- Name: retail_brands id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.retail_brands ALTER COLUMN id SET DEFAULT nextval('public.retail_brands_id_seq'::regclass);


--
-- Name: source_documents id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.source_documents ALTER COLUMN id SET DEFAULT nextval('public.source_documents_id_seq'::regclass);


--
-- Name: stores id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stores ALTER COLUMN id SET DEFAULT nextval('public.stores_id_seq'::regclass);


--
-- Name: text_extractions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.text_extractions ALTER COLUMN id SET DEFAULT nextval('public.text_extractions_id_seq'::regclass);


--
-- Name: active_storage_attachments active_storage_attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT active_storage_attachments_pkey PRIMARY KEY (id);


--
-- Name: active_storage_blobs active_storage_blobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs
    ADD CONSTRAINT active_storage_blobs_pkey PRIMARY KEY (id);


--
-- Name: active_storage_variant_records active_storage_variant_records_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT active_storage_variant_records_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: receipt_lines receipt_lines_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.receipt_lines
    ADD CONSTRAINT receipt_lines_pkey PRIMARY KEY (id);


--
-- Name: receipt_payments receipt_payments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.receipt_payments
    ADD CONSTRAINT receipt_payments_pkey PRIMARY KEY (id);


--
-- Name: receipt_promotions receipt_promotions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.receipt_promotions
    ADD CONSTRAINT receipt_promotions_pkey PRIMARY KEY (id);


--
-- Name: receipts receipts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.receipts
    ADD CONSTRAINT receipts_pkey PRIMARY KEY (id);


--
-- Name: retail_brands retail_brands_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.retail_brands
    ADD CONSTRAINT retail_brands_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: source_documents source_documents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.source_documents
    ADD CONSTRAINT source_documents_pkey PRIMARY KEY (id);


--
-- Name: stores stores_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stores
    ADD CONSTRAINT stores_pkey PRIMARY KEY (id);


--
-- Name: text_extractions text_extractions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.text_extractions
    ADD CONSTRAINT text_extractions_pkey PRIMARY KEY (id);


--
-- Name: index_active_storage_attachments_on_blob_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_active_storage_attachments_on_blob_id ON public.active_storage_attachments USING btree (blob_id);


--
-- Name: index_active_storage_attachments_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_attachments_uniqueness ON public.active_storage_attachments USING btree (record_type, record_id, name, blob_id);


--
-- Name: index_active_storage_blobs_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_blobs_on_key ON public.active_storage_blobs USING btree (key);


--
-- Name: index_active_storage_variant_records_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_variant_records_uniqueness ON public.active_storage_variant_records USING btree (blob_id, variation_digest);


--
-- Name: index_receipt_lines_on_receipt_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_receipt_lines_on_receipt_id ON public.receipt_lines USING btree (receipt_id);


--
-- Name: index_receipt_lines_on_receipt_id_and_position; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_receipt_lines_on_receipt_id_and_position ON public.receipt_lines USING btree (receipt_id, "position");


--
-- Name: index_receipt_payments_on_receipt_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_receipt_payments_on_receipt_id ON public.receipt_payments USING btree (receipt_id);


--
-- Name: index_receipt_payments_on_receipt_id_and_position; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_receipt_payments_on_receipt_id_and_position ON public.receipt_payments USING btree (receipt_id, "position");


--
-- Name: index_receipt_promotions_on_linked_line_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_receipt_promotions_on_linked_line_id ON public.receipt_promotions USING btree (linked_line_id);


--
-- Name: index_receipt_promotions_on_receipt_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_receipt_promotions_on_receipt_id ON public.receipt_promotions USING btree (receipt_id);


--
-- Name: index_receipts_on_source_document_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_receipts_on_source_document_id ON public.receipts USING btree (source_document_id);


--
-- Name: index_receipts_on_store_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_receipts_on_store_id ON public.receipts USING btree (store_id);


--
-- Name: index_receipts_on_store_register_ticket_purchased_at; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_receipts_on_store_register_ticket_purchased_at ON public.receipts USING btree (store_id, register_number, ticket_number, purchased_at) WHERE ((store_id IS NOT NULL) AND (register_number IS NOT NULL) AND (ticket_number IS NOT NULL) AND (purchased_at IS NOT NULL));


--
-- Name: INDEX index_receipts_on_store_register_ticket_purchased_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON INDEX public.index_receipts_on_store_register_ticket_purchased_at IS 'Soft duplicate guard. Intentionally excludes rows where any composite receipt identifier is NULL; source_documents.content_hash is the hard re-upload guard for exact duplicate files.';


--
-- Name: index_receipts_on_text_extraction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_receipts_on_text_extraction_id ON public.receipts USING btree (text_extraction_id);


--
-- Name: index_retail_brands_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_retail_brands_on_slug ON public.retail_brands USING btree (slug);


--
-- Name: index_source_documents_on_content_hash; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_source_documents_on_content_hash ON public.source_documents USING btree (content_hash);


--
-- Name: index_source_documents_on_store_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_source_documents_on_store_id ON public.source_documents USING btree (store_id);


--
-- Name: index_stores_on_retail_brand_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_stores_on_retail_brand_id ON public.stores USING btree (retail_brand_id);


--
-- Name: index_stores_on_retail_brand_id_and_location_name_and_channel; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_stores_on_retail_brand_id_and_location_name_and_channel ON public.stores USING btree (retail_brand_id, location_name, channel);


--
-- Name: index_text_extractions_on_source_document_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_text_extractions_on_source_document_id ON public.text_extractions USING btree (source_document_id);


--
-- Name: receipt_payments fk_rails_01cb4412a8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.receipt_payments
    ADD CONSTRAINT fk_rails_01cb4412a8 FOREIGN KEY (receipt_id) REFERENCES public.receipts(id);


--
-- Name: stores fk_rails_01d25a15c8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stores
    ADD CONSTRAINT fk_rails_01d25a15c8 FOREIGN KEY (retail_brand_id) REFERENCES public.retail_brands(id);


--
-- Name: receipts fk_rails_0b2f6f5e69; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.receipts
    ADD CONSTRAINT fk_rails_0b2f6f5e69 FOREIGN KEY (text_extraction_id) REFERENCES public.text_extractions(id);


--
-- Name: source_documents fk_rails_479c8da4db; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.source_documents
    ADD CONSTRAINT fk_rails_479c8da4db FOREIGN KEY (store_id) REFERENCES public.stores(id);


--
-- Name: receipts fk_rails_4e2f966342; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.receipts
    ADD CONSTRAINT fk_rails_4e2f966342 FOREIGN KEY (source_document_id) REFERENCES public.source_documents(id);


--
-- Name: receipts fk_rails_550c459587; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.receipts
    ADD CONSTRAINT fk_rails_550c459587 FOREIGN KEY (store_id) REFERENCES public.stores(id);


--
-- Name: receipt_lines fk_rails_611ac14192; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.receipt_lines
    ADD CONSTRAINT fk_rails_611ac14192 FOREIGN KEY (receipt_id) REFERENCES public.receipts(id);


--
-- Name: text_extractions fk_rails_848b654367; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.text_extractions
    ADD CONSTRAINT fk_rails_848b654367 FOREIGN KEY (source_document_id) REFERENCES public.source_documents(id);


--
-- Name: active_storage_variant_records fk_rails_993965df05; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT fk_rails_993965df05 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: active_storage_attachments fk_rails_c3b3935057; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT fk_rails_c3b3935057 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: receipt_promotions fk_rails_e0f65dc69f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.receipt_promotions
    ADD CONSTRAINT fk_rails_e0f65dc69f FOREIGN KEY (receipt_id) REFERENCES public.receipts(id);


--
-- Name: receipt_promotions fk_rails_f78688ae38; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.receipt_promotions
    ADD CONSTRAINT fk_rails_f78688ae38 FOREIGN KEY (linked_line_id) REFERENCES public.receipt_lines(id);


--
-- PostgreSQL database dump complete
--

\unrestrict HrK9WOEXcWw67ANSsqvmdNg93KcJQvRmfRhRev9IjWyMLZHf857N25eiWmrjOXH

--
-- PostgreSQL database dump
--

\restrict w1aj3kxRnLt5ed6dcvtUDMaAYtvnE3OvTWqP5dfXFhbzrbjdXgcvu2qcCtTHtmY

-- Dumped from database version 16.14 (Debian 16.14-1.pgdg13+1)
-- Dumped by pg_dump version 16.14 (Debian 16.14-1.pgdg13+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Data for Name: schema_migrations; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.schema_migrations (version) VALUES ('20260531093116');
INSERT INTO public.schema_migrations (version) VALUES ('20260601064235');
INSERT INTO public.schema_migrations (version) VALUES ('20260601085807');
INSERT INTO public.schema_migrations (version) VALUES ('20260601093241');
INSERT INTO public.schema_migrations (version) VALUES ('20260601104500');
INSERT INTO public.schema_migrations (version) VALUES ('20260601110500');
INSERT INTO public.schema_migrations (version) VALUES ('20260601111500');
INSERT INTO public.schema_migrations (version) VALUES ('20260601112500');
INSERT INTO public.schema_migrations (version) VALUES ('20260601113500');


--
-- PostgreSQL database dump complete
--

\unrestrict w1aj3kxRnLt5ed6dcvtUDMaAYtvnE3OvTWqP5dfXFhbzrbjdXgcvu2qcCtTHtmY

