"""Initial schema - PR-01 Core Data Models

Revision ID: 001
Revises: 
Create Date: 2024-12-14

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "001"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Create brons table
    op.create_table(
        "brons",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("name", sa.String(100), nullable=False),
        sa.Column("status", sa.String(20), nullable=False, server_default="idle"),
        sa.Column("current_task_id", sa.Uuid(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )

    # Create tasks table
    op.create_table(
        "tasks",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("title", sa.String(255), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("state", sa.String(20), nullable=False, server_default="draft"),
        sa.Column("category", sa.String(20), nullable=False, server_default="other"),
        sa.Column("progress", sa.Float(), nullable=False, server_default="0.0"),
        sa.Column("next_action", sa.String(255), nullable=True),
        sa.Column("waiting_on", sa.String(255), nullable=True),
        sa.Column("bron_id", sa.Uuid(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.ForeignKeyConstraint(["bron_id"], ["brons.id"]),
    )

    # Add foreign key from brons.current_task_id to tasks.id
    op.create_foreign_key(
        "fk_brons_current_task",
        "brons",
        "tasks",
        ["current_task_id"],
        ["id"],
    )

    # Create chat_messages table
    op.create_table(
        "chat_messages",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("role", sa.String(20), nullable=False),
        sa.Column("content", sa.Text(), nullable=False),
        sa.Column("task_state_update", sa.String(50), nullable=True),
        sa.Column("bron_id", sa.Uuid(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.ForeignKeyConstraint(["bron_id"], ["brons.id"]),
    )

    # Create ui_recipes table
    op.create_table(
        "ui_recipes",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("component_type", sa.String(30), nullable=False),
        sa.Column("schema", sa.JSON(), nullable=False, server_default="{}"),
        sa.Column("required_fields", sa.JSON(), nullable=False, server_default="[]"),
        sa.Column("title", sa.String(100), nullable=True),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("submitted_data", sa.JSON(), nullable=True),
        sa.Column("is_submitted", sa.Boolean(), nullable=False, server_default="0"),
        sa.Column("task_id", sa.Uuid(), nullable=True),
        sa.Column("message_id", sa.Uuid(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.ForeignKeyConstraint(["task_id"], ["tasks.id"]),
        sa.ForeignKeyConstraint(["message_id"], ["chat_messages.id"]),
    )

    # Create skills table
    op.create_table(
        "skills",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("name", sa.String(100), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("version", sa.Integer(), nullable=False, server_default="1"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )

    # Create skill_steps table
    op.create_table(
        "skill_steps",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("order", sa.Integer(), nullable=False),
        sa.Column("instruction", sa.Text(), nullable=False),
        sa.Column("requires_user_input", sa.Boolean(), nullable=False, server_default="0"),
        sa.Column("input_type", sa.String(50), nullable=True),
        sa.Column("skill_id", sa.Uuid(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.ForeignKeyConstraint(["skill_id"], ["skills.id"]),
    )

    # Create skill_parameters table
    op.create_table(
        "skill_parameters",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("name", sa.String(50), nullable=False),
        sa.Column("param_type", sa.String(20), nullable=False),
        sa.Column("required", sa.Boolean(), nullable=False, server_default="1"),
        sa.Column("default_value", sa.String(255), nullable=True),
        sa.Column("skill_id", sa.Uuid(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.ForeignKeyConstraint(["skill_id"], ["skills.id"]),
    )

    # Create indexes for common queries
    op.create_index("ix_tasks_bron_id", "tasks", ["bron_id"])
    op.create_index("ix_tasks_state", "tasks", ["state"])
    op.create_index("ix_chat_messages_bron_id", "chat_messages", ["bron_id"])
    op.create_index("ix_ui_recipes_task_id", "ui_recipes", ["task_id"])
    op.create_index("ix_skill_steps_skill_id", "skill_steps", ["skill_id"])


def downgrade() -> None:
    # Drop indexes
    op.drop_index("ix_skill_steps_skill_id")
    op.drop_index("ix_ui_recipes_task_id")
    op.drop_index("ix_chat_messages_bron_id")
    op.drop_index("ix_tasks_state")
    op.drop_index("ix_tasks_bron_id")

    # Drop tables in reverse order
    op.drop_table("skill_parameters")
    op.drop_table("skill_steps")
    op.drop_table("skills")
    op.drop_table("ui_recipes")
    op.drop_table("chat_messages")

    # Remove foreign key before dropping tasks
    op.drop_constraint("fk_brons_current_task", "brons", type_="foreignkey")

    op.drop_table("tasks")
    op.drop_table("brons")

