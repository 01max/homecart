--
-- PostgreSQL database dump
--

\restrict XcTvZlKfwzFA58DrQgftAigeSJFtpOBaQynk1v7oiMVh2qf85wKgqd2OTsOKWJ1

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
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: unaccent; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS unaccent WITH SCHEMA public;


--
-- Name: EXTENSION unaccent; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION unaccent IS 'text search dictionary that removes accents';


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
    'loyalty_cash_credit',
    'loyalty_cash_debit',
    'immediate_discount',
    'coupon',
    'points_accrual',
    'points_consumption'
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
    'vignette_count',
    'point_count'
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


--
-- Name: prevent_source_document_evidence_update(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.prevent_source_document_evidence_update() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF ROW(OLD.content_hash, OLD.mime_type, OLD.ingested_at)
    IS DISTINCT FROM ROW(NEW.content_hash, NEW.mime_type, NEW.ingested_at) THEN
    RAISE EXCEPTION 'source_documents evidence columns are immutable'
      USING ERRCODE = 'check_violation';
  END IF;

  RETURN NEW;
END;
$$;


--
-- Name: prevent_text_extraction_evidence_update(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.prevent_text_extraction_evidence_update() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF ROW(OLD.source_document_id, OLD.engine, OLD.text, OLD.ran_at, OLD.success, OLD.error_message)
    IS DISTINCT FROM ROW(NEW.source_document_id, NEW.engine, NEW.text, NEW.ran_at, NEW.success, NEW.error_message) THEN
    RAISE EXCEPTION 'text_extractions evidence columns are immutable'
      USING ERRCODE = 'check_violation';
  END IF;

  RETURN NEW;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: active_storage_attachments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_attachments (
    name character varying NOT NULL,
    record_type character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    blob_id uuid NOT NULL,
    record_id uuid NOT NULL
);


--
-- Name: active_storage_blobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_blobs (
    key character varying NOT NULL,
    filename character varying NOT NULL,
    content_type character varying,
    metadata text,
    service_name character varying NOT NULL,
    byte_size bigint NOT NULL,
    checksum character varying,
    created_at timestamp(6) without time zone NOT NULL,
    id uuid DEFAULT gen_random_uuid() NOT NULL
);


--
-- Name: active_storage_variant_records; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_variant_records (
    variation_digest character varying NOT NULL,
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    blob_id uuid NOT NULL
);


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
-- Name: categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.categories (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying NOT NULL,
    normalized_name character varying NOT NULL,
    slug character varying NOT NULL,
    parent_id uuid,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT categories_parent_not_self CHECK (((parent_id IS NULL) OR (parent_id <> id)))
);


--
-- Name: comparison_units; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.comparison_units (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying NOT NULL,
    symbol character varying NOT NULL,
    normalized_name character varying NOT NULL,
    slug character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: manufacturers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.manufacturers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying NOT NULL,
    normalized_name character varying NOT NULL,
    slug character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: product_brands; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.product_brands (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying NOT NULL,
    normalized_name character varying NOT NULL,
    slug character varying NOT NULL,
    retail_brand_id uuid,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: receipt_lines; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.receipt_lines (
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
    updated_at timestamp(6) without time zone NOT NULL,
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    receipt_id uuid NOT NULL
);


--
-- Name: receipt_payments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.receipt_payments (
    "position" integer NOT NULL,
    raw_label text NOT NULL,
    category public.receipt_payment_category NOT NULL,
    amount_cents integer NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    receipt_id uuid NOT NULL,
    CONSTRAINT receipt_payments_amount_cents_positive CHECK ((amount_cents > 0))
);


--
-- Name: receipt_promotions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.receipt_promotions (
    program character varying NOT NULL,
    unit public.receipt_promotion_unit NOT NULL,
    delta integer NOT NULL,
    label text,
    kind public.receipt_promotion_kind NOT NULL,
    linking_method public.receipt_promotion_linking_method NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    receipt_id uuid NOT NULL,
    linked_line_id uuid
);


--
-- Name: receipts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.receipts (
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
    updated_at timestamp(6) without time zone NOT NULL,
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    store_id uuid NOT NULL,
    source_document_id uuid NOT NULL,
    text_extraction_id uuid NOT NULL
);


--
-- Name: COLUMN receipts.purchased_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.receipts.purchased_at IS 'Wall-clock local transaction time, stored as printed or implied with no timezone offset applied. Drive and Click & Collect receipts use the PDF order-confirmation time.';


--
-- Name: retail_brands; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.retail_brands (
    name character varying NOT NULL,
    slug character varying NOT NULL,
    aliases jsonb DEFAULT '[]'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    id uuid DEFAULT gen_random_uuid() NOT NULL
);


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
    content_hash character varying NOT NULL,
    mime_type public.source_document_mime_type NOT NULL,
    ingested_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    parser_format public.parser_format NOT NULL,
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    store_id uuid NOT NULL
);


--
-- Name: stores; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.stores (
    location_name character varying NOT NULL,
    channel public.store_channel NOT NULL,
    address text,
    identifiers jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    retail_brand_id uuid NOT NULL
);


--
-- Name: text_extractions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.text_extractions (
    engine character varying NOT NULL,
    text text DEFAULT ''::text NOT NULL,
    ran_at timestamp(6) without time zone NOT NULL,
    success boolean DEFAULT false NOT NULL,
    error_message text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    source_document_id uuid NOT NULL
);


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
-- Name: categories categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_pkey PRIMARY KEY (id);


--
-- Name: comparison_units comparison_units_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comparison_units
    ADD CONSTRAINT comparison_units_pkey PRIMARY KEY (id);


--
-- Name: manufacturers manufacturers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.manufacturers
    ADD CONSTRAINT manufacturers_pkey PRIMARY KEY (id);


--
-- Name: product_brands product_brands_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_brands
    ADD CONSTRAINT product_brands_pkey PRIMARY KEY (id);


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
-- Name: index_categories_on_normalized_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_categories_on_normalized_name ON public.categories USING btree (normalized_name);


--
-- Name: index_categories_on_parent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_categories_on_parent_id ON public.categories USING btree (parent_id);


--
-- Name: index_categories_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_categories_on_slug ON public.categories USING btree (slug);


--
-- Name: index_comparison_units_on_normalized_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_comparison_units_on_normalized_name ON public.comparison_units USING btree (normalized_name);


--
-- Name: index_comparison_units_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_comparison_units_on_slug ON public.comparison_units USING btree (slug);


--
-- Name: index_comparison_units_on_symbol; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_comparison_units_on_symbol ON public.comparison_units USING btree (symbol);


--
-- Name: index_manufacturers_on_normalized_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_manufacturers_on_normalized_name ON public.manufacturers USING btree (normalized_name);


--
-- Name: index_manufacturers_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_manufacturers_on_slug ON public.manufacturers USING btree (slug);


--
-- Name: index_product_brands_on_normalized_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_product_brands_on_normalized_name ON public.product_brands USING btree (normalized_name);


--
-- Name: index_product_brands_on_retail_brand_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_product_brands_on_retail_brand_id ON public.product_brands USING btree (retail_brand_id);


--
-- Name: index_product_brands_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_product_brands_on_slug ON public.product_brands USING btree (slug);


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
-- Name: source_documents source_documents_evidence_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER source_documents_evidence_immutable BEFORE UPDATE OF content_hash, mime_type, ingested_at ON public.source_documents FOR EACH ROW EXECUTE FUNCTION public.prevent_source_document_evidence_update();


--
-- Name: text_extractions text_extractions_evidence_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER text_extractions_evidence_immutable BEFORE UPDATE OF source_document_id, engine, text, ran_at, success, error_message ON public.text_extractions FOR EACH ROW EXECUTE FUNCTION public.prevent_text_extraction_evidence_update();


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
-- Name: categories fk_rails_82f48f7407; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT fk_rails_82f48f7407 FOREIGN KEY (parent_id) REFERENCES public.categories(id);


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
-- Name: product_brands fk_rails_c55d12d216; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_brands
    ADD CONSTRAINT fk_rails_c55d12d216 FOREIGN KEY (retail_brand_id) REFERENCES public.retail_brands(id);


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

\unrestrict XcTvZlKfwzFA58DrQgftAigeSJFtpOBaQynk1v7oiMVh2qf85wKgqd2OTsOKWJ1

--
-- PostgreSQL database dump
--

\restrict Dba4tiLI2KxAo7ovJdFLmSDHt9PSPxNcnVS9RZV06XKVUrkWa08UGFYlawd1hs1

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
INSERT INTO public.schema_migrations (version) VALUES ('20260601124500');
INSERT INTO public.schema_migrations (version) VALUES ('20260601130500');
INSERT INTO public.schema_migrations (version) VALUES ('20260606200500');
INSERT INTO public.schema_migrations (version) VALUES ('20260614130000');
INSERT INTO public.schema_migrations (version) VALUES ('20260615191000');
INSERT INTO public.schema_migrations (version) VALUES ('20260608120000');
INSERT INTO public.schema_migrations (version) VALUES ('20260608121000');
INSERT INTO public.schema_migrations (version) VALUES ('20260608122000');
INSERT INTO public.schema_migrations (version) VALUES ('20260608123000');
INSERT INTO public.schema_migrations (version) VALUES ('20260608124000');


--
-- PostgreSQL database dump complete
--

\unrestrict Dba4tiLI2KxAo7ovJdFLmSDHt9PSPxNcnVS9RZV06XKVUrkWa08UGFYlawd1hs1
