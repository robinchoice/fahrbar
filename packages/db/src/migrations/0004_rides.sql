CREATE TABLE "mornings" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"practice_id" uuid NOT NULL,
	"date" date NOT NULL,
	"start" varchar(5) NOT NULL,
	"end" varchar(5) NOT NULL,
	"capacity" integer NOT NULL,
	"created_at" timestamp DEFAULT now() NOT NULL,
	CONSTRAINT "mornings_practice_id_date_unique" UNIQUE("practice_id","date")
);
--> statement-breakpoint
CREATE TABLE "practices" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"slug" varchar(40) NOT NULL,
	"name" varchar(120) NOT NULL,
	"address" varchar(200) NOT NULL,
	"created_at" timestamp DEFAULT now() NOT NULL,
	CONSTRAINT "practices_slug_unique" UNIQUE("slug")
);
--> statement-breakpoint
CREATE TABLE "rides" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"morning_id" uuid NOT NULL,
	"payload" text NOT NULL,
	"status" varchar(20) DEFAULT 'new' NOT NULL,
	"manage_token_hash" varchar(64) NOT NULL,
	"created_at" timestamp DEFAULT now() NOT NULL,
	CONSTRAINT "rides_manage_token_hash_unique" UNIQUE("manage_token_hash")
);
--> statement-breakpoint
CREATE TABLE "schedules" (
	"name" varchar(50) PRIMARY KEY NOT NULL,
	"next_run" timestamp DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "team_key" (
	"id" integer PRIMARY KEY DEFAULT 1 NOT NULL,
	"public_key" text NOT NULL,
	"encrypted_private_key" text NOT NULL,
	"salt" text NOT NULL,
	"iv" text NOT NULL,
	"iterations" integer NOT NULL,
	"created_at" timestamp DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "mornings" ADD CONSTRAINT "mornings_practice_id_practices_id_fk" FOREIGN KEY ("practice_id") REFERENCES "public"."practices"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "rides" ADD CONSTRAINT "rides_morning_id_mornings_id_fk" FOREIGN KEY ("morning_id") REFERENCES "public"."mornings"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "rides_morning_id_index" ON "rides" USING btree ("morning_id");